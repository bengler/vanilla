module UrlHelper

  def params_from_url(url)
    params = CGI.parse(URI.parse(url).query)
    Hash[*params.entries.map { |k, v| [k, v[0]] }.flatten].with_indifferent_access
  end

  def params_from_fragment(url)
    params = CGI.parse(URI.parse(url).fragment)
    Hash[*params.entries.map { |k, v| [k, v[0]] }.flatten].with_indifferent_access
  end

end
