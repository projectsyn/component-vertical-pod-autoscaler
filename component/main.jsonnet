// main template for vertical-pod-autoscaler
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': params.namespace,
      // Configure the namespaces so that the OCP4 cluster-monitoring
      // Prometheus can find the servicemonitors and rules.
      [if isOpenshift then 'openshift.io/cluster-monitoring']: 'true',
    },
  },
};

local namespacedName(name, namespace='') = {
  local namespacedName = std.splitLimit(name, '/', 1),
  local ns = if namespace != '' then namespace else params.namespace,
  namespace: if std.length(namespacedName) > 1 then namespacedName[0] else ns,
  name: if std.length(namespacedName) > 1 then namespacedName[1] else namespacedName[0],
};

local vpa_resources() = [
  local vpa = std.get(params.autoscaler, name);
  {
    apiVersion: 'autoscaling.k8s.io/v1',
    kind: 'VerticalPodAutoscaler',
    metadata: {
      name: namespacedName(name, '').name,
      namespace: namespacedName(name, '').namespace,
    },
    spec: {
      targetRef: {
        apiVersion: 'apps/v1',
        kind: std.get(vpa, 'kind', 'Deployment'),
        name: namespacedName(name, '').name,
      },
      updatePolicy: {
        updateMode: std.get(vpa, 'mode', 'Off'),
      },
    } + std.get(vpa, 'spec', {}),
  }
  for name in std.objectFields(params.autoscaler)
];

local adm_controller = import 'adm_controller.jsonnet';
local recommender = import 'recommender.jsonnet';
local updater = import 'updater.jsonnet';
local rbac = import 'rbac.jsonnet';

// Define outputs below
{
  '00_namespace': namespace,

  '20_recommender': recommender.deployment,
  [if !params.recommend_only then '30_adm_controller']: adm_controller.deployment,
  [if !params.recommend_only then '40_updater']: updater.deployment,

  '50_cluster_roles': rbac.cluster_roles,
  '50_cluster_role_bindings': rbac.cluster_role_bindings,
}
