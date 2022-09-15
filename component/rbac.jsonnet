// main template for vertical-pod-autoscaler
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

//
// Cluster Roles
//

local cr_metrics_reader = kube.ClusterRole('system:metrics-reader') {
  rules: [
    {
      apiGroups: [ 'metrics.k8s.io' ],
      resources: [ 'pods' ],
      verbs: [ 'get', 'list' ],
    },
  ],
};

local cr_actor = kube.ClusterRole('system:vpa-actor') {
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'pods', 'nodes', 'limitranges' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'events' ],
      verbs: [ 'get', 'list', 'watch', 'create' ],
    },
    {
      apiGroups: [ 'poc.autoscaling.k8s.io' ],
      resources: [ 'verticalpodautoscalers' ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
    {
      apiGroups: [ 'autoscaling.k8s.io' ],
      resources: [ 'verticalpodautoscalers' ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
  ],
};

local cr_checkpoint_actor = kube.ClusterRole('system:vpa-checkpoint-actor') {
  rules: [
    {
      apiGroups: [ 'poc.autoscaling.k8s.io' ],
      resources: [ 'verticalpodautoscalercheckpoints' ],
      verbs: [ 'get', 'list', 'watch', 'create', 'patch', 'delete' ],
    },
    {
      apiGroups: [ 'autoscaling.k8s.io' ],
      resources: [ 'verticalpodautoscalercheckpoints' ],
      verbs: [ 'get', 'list', 'watch', 'create', 'patch', 'delete' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'namespaces' ],
      verbs: [ 'get', 'list' ],
    },
  ],
};

local cr_evictioner = kube.ClusterRole('system:evictioner') {
  rules: [
    {
      apiGroups: [ 'apps', 'extensions' ],
      resources: [ 'replicasets' ],
      verbs: [ 'get' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'pods/eviction' ],
      verbs: [ 'create' ],
    },
  ],
};

local cr_target_reader = kube.ClusterRole('system:vpa-target-reader') {
  rules: [
    {
      apiGroups: [ '*' ],
      resources: [ '*/scale' ],
      verbs: [ 'get', 'watch' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'replicationcontrollers' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ 'apps' ],
      resources: [ 'daemonsets', 'deployments', 'replicasets', 'statefulsets' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ 'batch' ],
      resources: [ 'jobs', 'cronjobs' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local cr_status_reader = kube.ClusterRole('system:vpa-status-reader') {
  rules: [
    {
      apiGroups: [ 'coordination.k8s.io' ],
      resources: [ 'leases' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

//
// Cluster Role Bindings
//

local crb_metrics_reader = kube.ClusterRoleBinding('system:metrics-reader') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:metrics-reader',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-recommender',
      namespace: params.namespace,
    },
  ],
};

local crb_actor = kube.ClusterRoleBinding('system:vpa-actor') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:vpa-actor',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-recommender',
      namespace: params.namespace,
    },
    {
      kind: 'ServiceAccount',
      name: 'vpa-updater',
      namespace: params.namespace,
    },
  ],
};

local crb_checkpoint_actor = kube.ClusterRoleBinding('system:vpa-checkpoint-actor') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:vpa-checkpoint-actor',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-recommender',
      namespace: params.namespace,
    },
  ],
};

local crb_target_reader = kube.ClusterRoleBinding('system:vpa-target-reader') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:vpa-target-reader',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-recommender',
      namespace: params.namespace,
    },
    {
      kind: 'ServiceAccount',
      name: 'vpa-updater',
      namespace: params.namespace,
    },
    {
      kind: 'ServiceAccount',
      name: 'vpa-admission-controller',
      namespace: params.namespace,
    },
  ],
};

local crb_evictioner = kube.ClusterRoleBinding('system:vpa-evictioner') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:vpa-evictioner',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-updater',
      namespace: params.namespace,
    },
  ],
};

local crb_status_reader = kube.ClusterRoleBinding('system:vpa-status-reader') {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'system:vpa-status-reader',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'vpa-updater',
      namespace: params.namespace,
    },
  ],
};


{
  cr_metrics_reader: cr_metrics_reader,
  cr_actor: cr_actor,
  cr_checkpoint_actor: cr_checkpoint_actor,
  cr_evictioner: cr_evictioner,
  cr_target_reader: cr_target_reader,
  cr_status_reader: cr_status_reader,

  crb_metrics_reader: crb_metrics_reader,
  crb_actor: crb_actor,
  crb_checkpoint_actor: crb_checkpoint_actor,
  crb_target_reader: crb_target_reader,
  crb_evictioner: crb_evictioner,
  crb_status_reader: crb_status_reader,
}
