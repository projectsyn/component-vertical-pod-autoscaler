// main template for vertical-pod-autoscaler
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

local app_name = 'vpa-updater';

local deployment = kube.Deployment(app_name) {
  spec+: {
    template+: {
      spec+: {
        serviceAccountName: app_name,
        containers_:: {
          [app_name]: kube.Container(app_name) {
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.vpa_updater,
            resources: params.resources.vpa_updater,
            ports_:: {
              prometheus: { containerPort: 8943 },
            },
            env_:: {
              NAMESPACE: { fieldRef: { fieldPath: 'metadata.namespace' } },
            },
          },
        },
      },
    },
  },
};

local service_account = kube.ServiceAccount(app_name);

{
  deployment: deployment,
  service_account: service_account,
}
