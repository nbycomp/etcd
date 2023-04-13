local action = import 'action.libsonnet';
local job = import 'job.libsonnet';
local resource = import 'resource.libsonnet';

local repo = 'git@github.com:nbycomp/etcd.git';
local tag = 'v3.5.7';
local source = { branch: 'redhat-certified' };

{
  resources: [
    resource.repo_ci_tasks,
    resource.repo_pipeline(repo) {
      source+: source,
    },
    resource.repo('etcd-source', repo, source),
    resource.image('etcd-' + tag, 'registry.nearbycomputing.com/nearbyone/external/etcd-io/etcd', tag),
  ],

  jobs: [
    job.update_pipeline,
    {
      name: 'etcd-redhat-certified-build',
      public: true,
      plan: [
        {
          in_parallel: [
            {
              get: 'repo',
              resource: 'etcd-source',
              trigger: true,
            },
            action.get_ci_tasks,
          ],
        },
        action.build {
          params: {
            DOCKERFILE: 'repo/Dockerfile-release',
            TARGET: 'redhat-production',
          },
        },
        {
          put: 'etcd-' + tag,
          params: {
            image: 'image/image.tar',
          },
        },
      ],
    },
    {
      name: 'etcd-redhat-certified-verify',
      public: true,
      serial: true,
      plan: [
        {
          get: 'ci-tasks',
          trigger: true,
          passed: ['etcd-redhat-certified-build'],
        },
        {
          get: 'etcd-source',
          trigger: true,
          passed: ['etcd-redhat-certified-build'],
        },
        {
          task: 'verify-image',
          file: 'ci-tasks/redhat-preflight.yml',
          params: {
            IMAGE: '%s:%s' % ['registry.nearbycomputing.com/nearbyone/external/etcd-io/etcd', tag],
          },
        },
      ],
    },
  ],
}
