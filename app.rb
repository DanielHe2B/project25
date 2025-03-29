require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative './model.rb'
require 'sinatra/flash'

enable :sessions

@loggedin = 1

get('/') do
    if session[:id]
      db = connect_to_db('db/slutprojekt.db')
      user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
      @username = user['username'] if user
    end

    return slim(:start)
end

get('/showlogin') do

    return slim(:login)
end

get('/register') do

    return slim(:register)
end



post('/login') do
    username=params[:username]
    password=params[:password]
    db = connect_to_db('db/slutprojekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    if username == "" or password == ""
      failed("Please put fill all the boxes")
      redirect('/showlogin')
    end
    
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    if !result
      failed("Username does not exist")
      redirect('/showlogin')
    end
    passwordDigest = result["passwordDigest"] 
    id = result["id"]
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)

    if !result
      failed("Username does not exist")
      redirect('/showlogin')    
    end

    if BCrypt::Password.new(passwordDigest) == password
      session[:id] = id
      #@username= db.execute("SELECT * FROM users , WHERE id = ?", id)
      notice("Logged In")  
      redirect('/')

    else
      failed("Wrong password")
      redirect('/showlogin')
    end
end

post('/users/new') do
  username=params[:username]
  password=params[:password]
  password_confirm=params[:password_confirm]
  db = connect_to_db('db/slutprojekt.db')

  result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)

  if result
    validera("Username was taken")    
    redirect('/register')    
  end

  if (password==password_confirm) and ((password!="") and (password_confirm!="") and username!="")
    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?,?)", [username, password_digest])
    user_id = db.last_insert_row_id
    session[:id] = user_id
    redirect('/')
  elsif (password == "") or (password_confirm == "") or (username == "") or ((password == "") and (password_confirm == ""))
    validera("Please fill all the boxes")    
    redirect('/register')

  elsif (password!=password_confirm)
    validera("Please confirm the password")    
    redirect('/register')

  end
end

get('/logout') do
  session.clear
  notice("Du har loggats ut")
  redirect '/'
end