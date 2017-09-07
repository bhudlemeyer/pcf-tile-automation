# PCF Tile install Pipelines
For the most current base (opsmanager and ERT) pipelines please reference the [pcf-pipelines](https://github.com/pivotal-cf/pcf-pipelines) repo maintined by the team from Pivotal. 



This is a collection of [Concourse](https://concourse.ci) pipelines for
installing and upgrading [Pivotal Cloud Foundry](https://pivotal.io/platform) backing service tiles.

Specifically

* MySQL
* RabbitMQ
* Redis
* PCF Metrics
* JMX Bridge



## Usage

You'll need to [install a Concourse server](https://concourse.ci/installing.html)
and get the [Fly CLI](https://concourse.ci/fly-cli.html)
to interact with that server.

Depending on where you've installed Concourse, you may need to set up
[additional firewall rules](FIREWALL.md "Firewall") to allow Concourse to reach
third-party sources of pipeline dependencies.

Each pipeline has an associated `params.yml` file next to it that you'll need to fill out with the appropriate values for that pipeline.

After filling out your params.yml, set the pipeline:

```
fly -t yourtarget login --concourse-url https://yourtarget.example.com
fly -t yourtarget set-pipeline \
  --pipeline upgrade-opsman \
  --config upgrade-ops-manager/aws/pipeline.yml \
  --load-vars-from upgrade-ops-manager/aws/params.yml
```


Under the pipelines folder you will find a pipeline.yml for each backing service and the params.yml needed to make each one work correctly today. 


This is a new repo and does not currently have allot of smarts in the tasks IE if / that statements etc. As a result it is opinionated on what settings need to be provided and which are ignored for right now.



