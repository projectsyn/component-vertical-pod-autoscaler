local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.vertical_pod_autoscaler;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('vertical-pod-autoscaler', params.namespace);

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/vertical-pod-autoscaler' % appPath]: app,
}
