# APIcast Example Custom Policy
This policy is an example how to make custom policies for APIcast.

## OpenShift 3.11
To install this on OpenShift you can use provided template:
```shell
oc new-app -f apicast-requestid-policy.yml --param AMP_RELEASE=2.5.0
```

The template creates new ImageStream for images containing this policy.
Then it creates two BuildConfigs: one for building an image to apicast-policy ImageStream
and second one for creating new APIcast image copying just necessary code from that previous image.

after run command go to menu "Builds > Builds", You will find the 2 new Builds config.
*   apicast-requestid-policy
*   apicast-custom-policies


First click run "apicast-requestid-policy" to compile lua and create temp image.
Second click run "apicast-custom-policies" to copy policy to api-cast image and openshift will tags new api-case to lasted version.

## OpenShift 4
Create Secret
```shell
oc create secret generic custom-policy-requestid \
--from-file=./apicast-policy.json \
--from-file=./init.lua \
--from-file=./requestid.lua
```

Update APIManager CRD
```shell
spec:
  apicast:
    stagingSpec:
      customPolicies:
        - name: requestid
          version: "0.1"
          secretRef:
            name: custom-policy-requestid
```

### Custom Environment (default policy chain)
```shell
oc create secret generic custom-env-policy --from-file=./custom-env.lua
```

Update APIManager CRD
```shell
spec:
  apicast:
    productionSpec:
      customEnvironments:
        - secretRef:
            name: custom-env-policy
```

## lua script life cycle

```shell
local setmetatable = setmetatable

local _M = require('apicast.policy').new('Example', '0.1')
local mt = { __index = _M }

function _M.new()
return setmetatable({}, mt)
end

function _M:init()
-- do work when nginx master process starts
end

function _M:init_worker()
-- do work when nginx worker process is forked from master
end

function _M:rewrite()
-- change the request before it reaches upstream
ngx.req.set_header('X-CustomPolicy', 'customValue')
end

function _M:access()
-- ability to deny the request before it is sent upstream
end

function _M:content()
-- can create content instead of connecting to upstream
end

function _M:post_action()
-- do something after the response was sent to the client
end

function _M:header_filter()
-- can change response headers
end

function _M:body_filter()
-- can read and change response body
-- https://github.com/openresty/lua-nginx-module/blob/master/README.markdown#body_filter_by_lua
end

function _M:log()
-- can do extra logging
end

function _M:balancer()
-- use for example require('resty.balancer.round_robin').call to do load balancing
end

return _M
```

