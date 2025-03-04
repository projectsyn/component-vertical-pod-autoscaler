// main template for vertical-pod-autoscaler
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

local isOpenshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);

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

local cert_manager_issuer = {
  apiVersion: 'cert-manager.io/v1',
  kind: 'Issuer',
  metadata: {
    name: 'vpa-admission-controller',
    namespace: params.namespace,
  },
  spec: {
    selfSigned: {},
  },
};

local cert_manager_cert = {
  apiVersion: 'cert-manager.io/v1',
  kind: 'Certificate',
  metadata: {
    name: 'vpa-admission-controller',
  },
  spec: {
    secretName: 'vpa-tls-certs',
    dnsNames: [
      '%(service)s.%(namespace)s.svc' % { service: 'vpa-webhook', namespace: params.namespace },
    ],
    issuerRef: {
      name: 'vpa-admission-controller',
      kind: 'Issuer',
      group: 'cert-manager.io',
    },
  },
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

local vpa_aggregated_roles = [
  kube.ClusterRole('syn:vertical-pod-autoscaler:view') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
        'rbac.authorization.k8s.io/aggregate-to-view': 'true',
        'rbac.authorization.k8s.io/aggregate-to-cluster-reader': 'true',
      },
    },
    rules: [
      {
        apiGroups: [ 'autoscaling.k8s.io' ],
        resources: [ 'verticalpodautoscalers' ],
        verbs: [ 'get', 'list', 'watch' ],
      },
    ],
  },
  kube.ClusterRole('syn:vertical-pod-autoscaler:edit') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      },
    },
    rules: [
      {
        apiGroups: [ 'autoscaling.k8s.io' ],
        resources: [ 'verticalpodautoscalers' ],
        verbs: [
          'create',
          'delete',
          'deletecollection',
          'patch',
          'update',
        ],
      },
    ],
  },
  kube.ClusterRole('syn:vertical-pod-autoscaler:cluster-reader') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-cluster-reader': 'true',
      },
    },
    rules: [
      {
        apiGroups: [ 'autoscaling.k8s.io' ],
        resources: [ 'verticalpodautoscalercheckpoints' ],
        verbs: [ 'get', 'list', 'watch' ],
      },
    ],
  },
];

// Define outputs below
{
  '00_namespace': namespace,
  '20_aggregated_rbac': vpa_aggregated_roles,

  [if params.allow_autoscaling then '50_vpa_certs']: [ cert_manager_issuer, cert_manager_cert ],
  [if std.length(params.autoscaler) > 0 then '60_vpa_resources']: vpa_resources(),
}
