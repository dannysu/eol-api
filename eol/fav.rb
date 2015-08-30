require 'rubygems'
require 'sinatra'
require 'json'
require 'sqlite3'

get '/fav' do
  content_type 'application/javascript'

  begin
    db = SQLite3::Database.new('db/favourites.sqlite3')

    stmt = db.prepare <<SQL
      CREATE TABLE IF NOT EXISTS favourites (
      link TEXT PRIMARY KEY,
      image TEXT,
      filename TEXT,
      name TEXT)
SQL
    stmt.execute()

    result = Hash.new
    result['success'] = false

    if params['link'] and params['image'] and params['filename'] and params['name'] then
      if params['pass'] == ENV['EOL_FAV_PASSWORD'] then
        db.transaction do |db|
          db.execute("DELETE FROM favourites WHERE link = ?", params['link'])

          if params['action'] == 'add' then
            db.execute("INSERT INTO favourites (link, image, filename, name) VALUES (?, ?, ?, ?)", params['link'], params['image'], params['filename'], params['name'])
          end

          result['success'] = true
        end
      end
    else
      result['total_items'] = db.get_first_value("SELECT COUNT(*) AS count FROM favourites")

      page = [params['page'].to_i > 0 ? params['page'].to_i - 1 : 0, 0].max
      offset = page * 25

      result['start'] = offset + 1
      result['end'] = offset + 25

      items = []
      db.execute("SELECT * FROM favourites LIMIT 25 OFFSET ?", offset) {|row|
        items << {'link' => row[0], 'source' => row[1], 'filename' => row[2], 'name' => row[3]}
      }
      result['collection_items'] = items
      result['success'] = true
    end

  rescue SQLite3::Exception => e

    result = Hash.new
    result['error'] = "Exception occured"

  rescue Exception => e

    result['error'] = e.message

  ensure
    stmt.close if stmt
    db.close if db
  end

  if params['callback'] and params['callback'].length > 0 then
    params['callback'] + "(" + result.to_json + ");"
  else
    result.to_json
  end
end
