// main template for cm-hetznercloud
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

local vpa = com.Kustomization(
  'https://github.com/kubernetes/autoscaler//vertical-pod-autoscaler/deploy',
  params.manifestVersion,
  {
    'registry.k8s.io/autoscaling/vpa-admission-controller': {
      newTag: params.images.vpa_admission_controller.tag,
      newName: '%(registry)s/%(repository)s' % params.images.vpa_admission_controller,
    },
    'registry.k8s.io/autoscaling/vpa-recommender': {
      newTag: params.images.vpa_recommender.tag,
      newName: '%(registry)s/%(repository)s' % params.images.vpa_recommender,
    },
    'registry.k8s.io/autoscaling/vpa-updater': {
      newTag: params.images.vpa_updater.tag,
      newName: '%(registry)s/%(repository)s' % params.images.vpa_updater,
    },
  },
  {
    patches: [
      {
        patch: |||
          - op: remove
            path: "/spec/template/spec/securityContext/runAsUser"
        |||,
        target: {
          kind: 'Deployment',
        },
      },
    ] + (
      if std.length(params.recommender_args) == 0 then [] else [
        {
          patch: |||
            - op: add
              path: "/spec/template/spec/containers/0/args"
              value: [%s]
          ||| % std.join(',', params.recommender_args),
          target: {
            kind: 'Deployment',
            name: 'vpa-recommender',
          },
        },
      ]
    ) + (
      if std.length(params.updater_args) == 0 then [] else [
        {
          patch: |||
            - op: add
              path: "/spec/template/spec/containers/0/args"
              value: [%s]
          ||| % std.join(',', params.updater_args),
          target: {
            kind: 'Deployment',
            name: 'vpa-updater',
          },
        },
      ]
    ) + (
      if params.allow_autoscaling then [
        {
          patch: |||
            - op: add
              path: "/spec/template/spec/containers/0/args/-"
              value: "--client-ca-file=/etc/tls-certs/ca.crt"
            - op: add
              path: "/spec/template/spec/containers/0/args/-"
              value: "--tls-cert-file=/etc/tls-certs/tls.crt"
            - op: add
              path: "/spec/template/spec/containers/0/args/-"
              value: "--tls-private-key=/etc/tls-certs/tls.key"
          |||,
          target: {
            kind: 'Deployment',
            name: 'vpa-admission-controller',
          },
        },
      ] else [
        {
          patch: |||
            - op: remove
              path: "/subjects/1"
          |||,
          target: {
            kind: 'ClusterRoleBinding',
            name: 'system:vpa-actor',
          },
        },
        {
          patch: |||
            - op: remove
              path: "/subjects/2"
            - op: remove
              path: "/subjects/1"
          |||,
          target: {
            kind: 'ClusterRoleBinding',
            name: 'system:vpa-target-reader-binding',
          },
        },
      ]
    ),
    [if !params.allow_autoscaling then 'patchesStrategicMerge']: [
      'rm-autoscaling.yaml',
    ],
  } + com.makeMergeable(params.kustomizeInput),
) {
  'rm-autoscaling': [
    // Admission Controller
    {
      '$patch': 'delete',
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'vpa-admission-controller',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'vpa-admission-controller',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'vpa-webhook',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'system:vpa-admission-controller',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'system:vpa-admission-controller',
      },
    },
    // Updater
    {
      '$patch': 'delete',
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'vpa-updater',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'vpa-updater',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'system:evictioner',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'system:vpa-evictioner-binding',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'system:vpa-status-reader',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'system:vpa-status-reader-binding',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'Role',
      metadata: {
        name: 'system:leader-locking-vpa-updater',
        namespace: 'kube-system',
      },
    },
    {
      '$patch': 'delete',
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'RoleBinding',
      metadata: {
        name: 'system:leader-locking-vpa-updater',
        namespace: 'kube-system',
      },
    },
  ],
};

vpa
