require 'rubygems'
require 'sinatra'
require 'json'
require 'open-uri'
require 'nokogiri'
require 'digest'

get '/api' do
  content_type 'application/javascript'
  url = 'http://eol.org/search?commit=Filter&type%5B%5D=Image&q='

  result = Hash.new

  if params['page'].to_i >= 1 then
    url += URI::encode(params['q'])
    url += "&page=" + params['page']

    cache_file = "cache/" + Digest::MD5.hexdigest(url)
    if File.exists? cache_file and Time.now - File.mtime(cache_file) < 24 * 60 * 60 then
      f = File.open(cache_file)
      doc = Nokogiri::HTML(f)
      f.close()
    else
      content = open(url).read
      f = File.open(cache_file, 'w')
      f.write(content)
      f.close()
      doc = Nokogiri::HTML(content)
    end

    if doc.css("div[class=media]").length > 0 then
      result['total_items'] = 1
      result['start'] = 1
      result['end'] = 1

      item = Hash.new
      item['source'] = doc.at_css("div[class=media]").at_css("img")['src'].gsub("_580_360", "_88_88")
      item['link'] = doc.at_css("link[rel=canonical]")['href'].gsub("http://eol.org", "")
      item['filename'] = doc.at_css("div[class=hgroup]/h1").inner_html
      item['name'] = ''
      result['collection_items'] = Array.new
      result['collection_items'] << item
    else
      # Find total number of images
      count_text = ''
      if doc.css("div[class=header]/h3").length > 0 then
        count_text = doc.at_css("div[class=header]/h3").inner_html
      end
      words = count_text.split
      if words.length >= 4 then
        result['total_items'] = words[words.length - 1].to_i
        result['start'] = words[1].to_i
        result['end'] = words[3].to_i
      else
        result['total_items'] = 0
        result['start'] = 0
        result['end'] = 0
      end

      # Find images on the page
      items = Array.new
      doc.css("li[class=image]").each do |item|
        obj = Hash.new

        if item.css("img").length > 0 then
          obj['source'] = item.at_css("img")['src']
        else
          obj['source'] = ''
        end

        links = item.css("a")
        if links.length >= 4 then
          obj['link'] = links[0]['href']
          obj['filename'] = links[2].content
          obj['name'] = links[3].content
        else
          obj['link'] = ''
          obj['filename'] = ''
          obj['name'] = ''
        end

        items << obj

      end
      result['collection_items'] = items
    end
  else
    result['error'] = 'Invalid page number'
  end

  if params['callback'] and params['callback'].length > 0 then
    params['callback'] + "(" + result.to_json + ");"
  else
    result.to_json
  end
end
