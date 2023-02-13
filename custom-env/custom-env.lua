local cjson = require('cjson')
local PolicyChain = require('apicast.policy_chain')
local policy_chain = context.policy_chain

local cors_policy_config = cjson.decode([[
{
    "allow_headers": [
        "Accept,Accept-Charset,Authorization,Content-Length,Content-Type,Host,Origin,Protocol,Server,SoapAction,User-Agent,X-Forwarded-For,X-Forwarded-Port,X-Forwarded-Proto"
    ],
    "allow_methods":[
        "POST"
    ],
    "allow_credentials": true
}
]])

local caching_policy_config = cjson.decode([[
{
    "caching_type": "strict"
}
]])

policy_chain:insert( PolicyChain.load_policy('requestid', '0.1', '{}'), 1)
policy_chain:insert( PolicyChain.load_policy('cors', 'builtin', cors_policy_config), 1)
policy_chain:insert( PolicyChain.load_policy('caching', 'builtin', caching_policy_config), 1)

return {
  policy_chain = policy_chain,
  port = { metrics = 9421 },
}