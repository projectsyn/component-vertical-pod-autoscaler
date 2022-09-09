local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.vertical_pod_autoscaler;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('vertical-pod-autoscaler', params.namespace);

{
  'vertical-pod-autoscaler': app,
}
