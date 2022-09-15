// main template for vertical-pod-autoscaler
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.vertical_pod_autoscaler;

local app_name = 'vpa-admission-controller';

local deployment = kube.Deployment(app_name) {
  spec+: {
    template+: {
      spec+: {
        serviceAccountName: app_name,
        containers_:: {
          [app_name]: kube.Container(app_name) {
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.vpa_admission_controller,
            resources: params.resources.vpa_admission_controller,
            args: [
              '--client-ca-file=/etc/tls-certs/ca.crt',
              '--tls-cert-file=/etc/tls-certs/tls.crt',
              '--tls-private-key=/etc/tls-certs/tls.key',
            ],
            ports_:: {
              http: { containerPort: 8000 },
              prometheus: { containerPort: 8944 },
            },
            env_:: {
              NAMESPACE: { fieldRef: { fieldPath: 'metadata.namespace' } },
            },
            volumeMounts_:: {
              'tls-certs': { readOnly: true, mountPath: '/etc/tls-certs' },
            },
          },
        },
        volumes_:: {
          'tls-certs': { secret: { secretName: 'vpa-tls-certs' } },
        },
      },
    },
  },
};

local service = kube.Service(app_name) {
  target_pod:: deployment.spec.template,
  target_container_name:: app_name,
  spec+: {
    sessionAffinity: 'None',
  },
};

local service_account = kube.ServiceAccount(app_name);

local cert_manager_issuer = {
  apiVersion: 'cert-manager.io/v1',
  kind: 'Issuer',
  metadata: {
    name: app_name,
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
    name: app_name,
  },
  spec: {
    secretName: 'vpa-tls-certs',
    dnsNames: [
      '%(service)s.%(namespace)s.svc' % { service: app_name, namespace: params.namespace },
    ],
    issuerRef: {
      name: app_name,
      kind: 'Issuer',
      group: 'cert-manager.io',
    },
  },
};

{
  deployment: [
    deployment,
    service,
    service_account,
    cert_manager_issuer,
    cert_manager_cert,
  ],
}
