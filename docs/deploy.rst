Deploy
======

Central Brilview is hosted at CERN web services: https://webservices.web.cern.ch/webservices/Services/ManageSite/default.aspx?SiteName=brilview

All instructions bellow assume that you are inside ``openshift`` directory of
the Brilview project.

First time setup
----------------

Create CVMFS volume claim
^^^^^^^^^^^^^^^^^^^^^^^^^

Go to project web console https://openshift.cern.ch/console/project/brilview/

1. "Storage" -> "Create Storage"
2. Fill the form:

   a. "Storage Class": cvmfs-cms-bril.cern.ch
   b. "Name": cvmfs-bril
   c. "Access Mode": Read Only (ROX)
   d. "Size": O MiB

3. Click "Create"

Deploy Brilview containers
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. highlight:: bash
::

  oc create -f nginx/template.yaml
  oc start-build nginx-bc --from-dir=nginx
  oc create -f brilview/template.yaml
  oc start-build brilview-server-bc --from-dir=brilview
  oc create -f client-compiler/template.yaml
  oc start-build client-compiler-bc --from-dir=client-compiler
  oc create -f grafana-influxdb/template.yaml
  oc start-build grafana-influxdb-bc --from-dir=grafana-influxdb

Do not worry if nginx container is "crashing frequently" until client files are
compiled. Health check fails until nginx can serve index file.

Add CERN SSO
^^^^^^^^^^^^

Go to project web console https://openshift.cern.ch/console/project/brilview/
and add cern-sso-proxy:

1. "Add to project" -> "Uncategorized" -> "cern-sso-proxy"
2. chose e-groups in AUTHORIZED_GROUPS (e.g. 'cern-users', 'cern-staff', 'CMS-BRIL-Project')
3. point to nginx-service in SERVICE_NAME
4. Click "Create"
5. Increase route timeout with command ``oc annotate route cern-sso-proxy --overwrite haproxy.router.openshift.io/timeout=600s``


Build frontend client
^^^^^^^^^^^^^^^^^^^^^

After all builds and deployments are finished see section :ref:`update-client` to
fetch client side code from git repository, run build process and populate
shared volume for nginx to serve.

Make Brilview public
^^^^^^^^^^^^^^^^^^^^

Change website visibility from "Intranet" to "Internet": https://cern.service-now.com/service-portal/article.do?n=KB0004359

.. _update-client:
Updating client
---------------

Temporarily scale down ``brilview-server`` pods from 2 to 1 to free some resources
for client building, then scale up client-compiler from 0 to 1, watch logs, when
finished, scale client-compiler back to 0 and scale brilview-server back to 2.

Updating server
---------------

::

  oc start-build brilview-server-bc --from-dir=brilview

Monitoring
----------

Find pod containing Grafana::

  oc get pods

Forward port 3000 to your machine::

  oc port-forward 3000 grafana-influxdb-dc-<some_identifiers_you_found_with_above_command>

Visit ``localhost:3000``. If it is first time after Grafana deployment, then
login with user:``admin`` and pass:``admin``, add influxdb source
(name:``my-influx``, type:``InfluxDB``, url:``http://localhost:8086``,
access:``proxy``, database:``telegraf``). Now either make whatever dashboard or
import (copy/paste) ``grafana-influxdb/dashboard.json`` and then change
hostnames for all graphs (Grafana queries influxdb and gives suggestions in
dropdowns) to match current ones.

Tips
----

If there is no space (or you want more resources) for build/deploy containers -
scale down ``brilview-server`` to one pod, do stuff, then scale back to 2.
