def connect_to_db(path)
    db=SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

def validera(felmeddelande)
    return flash[:validate] = felmeddelande
end

def failed(felmeddelande)
    return flash[:fail] = felmeddelande
end

def notice(felmeddelande)
    return flash[:notice] = felmeddelande
end

def existing_username()
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    return result
end