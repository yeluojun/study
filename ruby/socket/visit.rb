require 'rubygems'
require 'rest-client'
RestClient.proxy = 'http://0.0.0.0:8088'
# data = RestClient.get('http://baidu.com')


data = RestClient.post('http://baidu.com:8888', {a: 9, b:89 })

p data