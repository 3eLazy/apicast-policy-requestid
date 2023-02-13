--- Gen RQUUID and remove Response Headers policy

local policy = require('apicast.policy')
local _M = policy.new('requestid', '0.1')
local new = _M.new

local t_header = ''
local k_headers = ''
local t_rquuid = ''

function _M.new(config)
    local self = new(config)

    self.t_header = config.to_header or 'breadcrumbId'
    self.k_headers = config.keep_headers or 'novalue'

    ngx.log(ngx.DEBUG, 'set rquuid to header name: ', t_header)
    ngx.log(ngx.DEBUG, 'list headers to keep: ', k_headers)

    return self
end

function _M:init()
    -- do work when nginx master process starts
end

function _M:init_worker()
    -- do work when nginx worker process is forked from master
end

function _M:rewrite()
    -- change the request before it reaches upstream
    local random = math.random

    local rq_time = ngx.req.start_time()
    local rq_dt = os.date('%Y%m%d%H%M%S', rq_time)
    local template ='xxxxxxxxxxxxyyxxxxxxxxxxxxxxyy'
    local rq_uuid_rand = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)

    local header_val = self.t_header
    local rq_uuid = rq_dt .. "-" .. rq_uuid_rand
    self.t_rquuid = rq_uuid
    ngx.log(ngx.DEBUG, 'generated rquuid = ', t_rquuid)
    ngx.req.set_header(header_val, rq_uuid)
    --local rq_app_id = ngx.req.get_headers()['app_id']
    local rq_app_key = ngx.req.get_headers()['app_key']
    local rq_user_key = ngx.req.get_headers()['user_key']
    local rq_bearer = ngx.req.get_headers()['Authorization']
    if rq_app_key ~= nil then
        ngx.req.clear_header('app_key')
    end
    if rq_user_key ~= nil then
        ngx.req.clear_header('user_key')
    end
    if rq_bearer ~= nil then
        ngx.req.clear_header('Authorization')
    end

    ngx.log(ngx.WARN, 'In coming request: {"',header_val,'":"',rq_uuid,'","body":"',ngx.var.request_body,'"}')
    ngx.header['Server'] = 'Unknown'
    ngx.header['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
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
    local header_to_keep = self.k_headers
    ngx.log(ngx.DEBUG, 'header to keep = ', header_to_keep)
    local rs_h, err = ngx.resp.get_headers()

    if err == "truncated" then
        -- one can choose to ignore or reject the current response here
        ngx.log(ngx.DEBUG, 'Cannot read response header')
    else
        local keep_h = '0'
        local xh = ''
        local cmh = ''
        for k, v in pairs(rs_h) do
            ngx.log(ngx.DEBUG, 'header = ', k)
            xh = string.sub(k, 1, 2)
            cmh = string.sub(k, 1, 5)
            -- app_id, app_key and user_key cannot remove from response header, it can remove on request only
            if xh == 'x-' or cmh == 'camel' or k == 'forwarded' then
                keep_h = '0'
                if k == 'x-transaction-id' or k == 'x-correlation-id' or k == 'x-salt-hex' or k == 'x-content-type-options' or k == 'x-xss-protection' then
                    keep_h = '1'
                    ngx.log(ngx.DEBUG, 'keep header = ', k)
                elseif header_to_keep ~= nil or header_to_keep ~= 'novalue' then
                    for htk in string.gmatch(header_to_keep, "([^"..",".."]+)") do
                        ngx.log(ngx.DEBUG, 'input keep header = ', htk)
                        if k == string.lower(htk) then
                            keep_h = '1'
                            ngx.log(ngx.DEBUG, 'keep header = ', k)
                            break
                        end
                    end
                end

                if keep_h == '0' then
                    ngx.header[k] = nil
                    ngx.log(ngx.DEBUG, 'header set to nil = ', k)
                end
            end
        end
        ngx.header['Server'] = 'Unknown'
        ngx.header['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end
end

function _M:body_filter()
    -- can read and change response body
    -- https://github.com/openresty/lua-nginx-module/blob/master/README.markdown#body_filter_by_lua
    local header_val = self.t_header
    local rq_uuid = self.t_rquuid
    local resp_body = string.sub(ngx.arg[1], 1, 1000)
    ngx.ctx.buffered = (ngx.ctx.buffered or "") .. resp_body
    if ngx.arg[2] then
        resp_body = ngx.ctx.buffered
    end
    ngx.log(ngx.WARN, 'Out going response: {"',header_val,'":"',rq_uuid,'", "body":"',resp_body,'"}')
end

function _M:log()
  -- can do extra logging
end

function _M:balancer()
  -- use for example require('resty.balancer.round_robin').call to do load balancing
end

return _M