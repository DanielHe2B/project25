def connect_to_db(path)
    db=SQLite3::Database.new(path)
    db.results_as_hash = true
    db.busy_timeout(1000) 
    return db
end