# config

```bash
    config [<parameter[=value]
```

          Show/Set site specific parameters.Running it  without  any  argument
          shows all the available parameters and their values for your site.

          OPTIONS

          <paramter>
             Shows current and valid values for <paramter>.

          <paramter>=<value>
             Set new <value> for the <paramter>.

          Supported site configuration parameters are

             release-checks=1|0|yes|no
                Enable/disable  release  checks e.g. production architectures,
                deprecated releases.  This avoids accessing releases  informa-
                tion from internet. Default value is 1.

             release-checks-timeout=[3-9]|[1-9][0-9]+
                Time  in seconds after which a request to get release informa-
                tion should be timed out (min. value  3s).  Default  value  is
                10s.