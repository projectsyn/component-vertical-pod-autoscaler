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
    },
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

  '20_adm_controller_deploy': adm_controller.deployment,
  '21_adm_controller_svc': adm_controller.service,
  '22_adm_controller_sa': adm_controller.service_account,
  '23_adm_controller_cr': adm_controller.cluster_role,
  '24_adm_controller_crb': adm_controller.cluster_role_binding,
  '25_cert_manager_issuer': adm_controller.cert_manager_issuer,
  '26_cert_manager_cert': adm_controller.cert_manager_cert,

  '30_recommender_deploy': recommender.deployment,
  '32_recommender_sa': recommender.service_account,

  '40_updater_deploy': updater.deployment,
  '42_updater_sa': updater.service_account,

  '53_cr_metrics_reader': rbac.cr_metrics_reader,
  '53_cr_actor': rbac.cr_actor,
  '53_cr_checkpoint_actor': rbac.cr_checkpoint_actor,
  '53_cr_evictioner': rbac.cr_evictioner,
  '53_cr_target_reader': rbac.cr_target_reader,
  '53_cr_status_reader': rbac.cr_status_reader,

  '54_crb_metrics_reader': rbac.crb_metrics_reader,
  '54_crb_actor': rbac.crb_actor,
  '54_crb_checkpoint_actor': rbac.crb_checkpoint_actor,
  '54_crb_target_reader': rbac.crb_target_reader,
  '54_crb_evictioner': rbac.crb_evictioner,
  '54_crb_status_reader': rbac.crb_status_reader,

  '60_vpa_resources': vpa_resources(),
}
