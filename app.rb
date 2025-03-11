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
    passwordDigest = result["passwordDigest"] 
    id = result["id"]
  
    if BCrypt::Password.new(passwordDigest) == password
      session[:id] = id
      @loggedin=2
      #@username= db.execute("SELECT * FROM users , WHERE id = ?", id)
      flash[:notice] = "Logged In"
      redirect('/')
    else
      flash[:fail] = "Wrong password"
      redirect('/showlogin')
    end
end

post('/users/new') do
  username=params[:username]
  password=params[:password]
  password_confirm=params[:password_confirm]

  if (password==password_confirm)
    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?,?)", [username, password_digest])
    redirect('/')
  elsif (password == "") or (password_confirm == "") or (username == "")
    flash[:validate] = "Please fill all the boxes"
    redirect('/register')

  elsif (password!=password_confirm)
    flash[:validate] = "Please confirm the password"
    redirect('/register')

  end
end