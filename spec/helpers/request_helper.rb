module RequestHelper

  def do_request_with_body(method, path, params, body, env = {})
    if body.is_a?(String)
      send(method, path, params, env.merge(
        'HTTP_CONTENT_TYPE' => 'application/octet-stream',
        'rack.input' => StringIO.new(body)))
    else
      body = JSON.dump(body)
      send(method, path, params, env.merge(
        'CONTENT_TYPE' => 'application/json',
        'rack.input' => StringIO.new(body)))
    end
  end

  def post_body(path, params, body, env = {})
    do_request_with_body(:post, path, params, body, env)
  end

  def put_body(path, params, body, env = {})
    do_request_with_body(:put, path, params, body, env)
  end

  def encode_params_base64(params)
    query = params.map { |(k, v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
    s = Base64.encode64(query)
    s.gsub!(/(\s|==$)/, '')
    s
  end

end
