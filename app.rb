require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative './model.rb'
require 'sinatra/flash'

enable :sessions

include Model

get('/') do #visar hemsidan
    if session[:id]
      db = connect_to_db('db/slutprojekt.db')
      user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
      @username = user['username'] if user
    end

    db = connect_to_db('db/slutprojekt.db')
    @products = db.execute("SELECT * FROM productinfo")  
    return slim(:show)
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

    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    passwordDigest = result["passwordDigest"] 
    id = result["id"]

    
    if BCrypt::Password.new(passwordDigest) == password
      session[:id] = id
      @username= db.execute("SELECT * FROM users WHERE id = ?", id)
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
  notice("You have logged out")
  redirect('/')
end

get('/product_new') do

  return slim(:new)
end

post('/products/create') do
  # Kontrollera om användaren är inloggad och har admin-rättigheter
  #p @username.to_s.downcase
  #redirect '/' unless @username.to_s.downcase == "admin"
  
  # Hämta formulärdata
  productname = params['productname']
  description = params['description']
  price = params['price'].to_f
  image = params['image']
  
  # Lägg till i databasen (exempel med SQLite)
  db = connect_to_db('db/slutprojekt.db')
  db.execute("INSERT INTO productinfo (productname, price, description, image) VALUES (?, ?, ?, ?)", [productname, price, description, image])
  
  notice("Product successfully added")
  redirect('/')
end

post('/product/:id/delete') do
  # Check if user is logged in and is admin
  #redirect '/login' unless session[:user_id]
  
  id = params['id']
  
  # Delete the product from database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("DELETE FROM productinfo WHERE id = ?", [id])
  
  notice("Product successfully removed")
  redirect('/')
end

get('/product/edit/:id') do
  @id = params[:id]
  return slim(:edit)
end

post('/product/:id/update') do
  productname = params['new_productname']
  description = params['new_description']
  price = params['new_price'].to_f
  image = params['new_image']
  id = params['id']
  p [productname, price, description, image, id] 
  db = connect_to_db('db/slutprojekt.db')

  db.execute("UPDATE productinfo SET productname = ?, price = ?, description = ?, image = ? WHERE id = ?",
    [productname, price, description, image, id])  
  notice("Productinfo successfully changed")
  redirect('/')
end

get('/shoppingcart') do
  
  db = connect_to_db('db/slutprojekt.db')
  user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
  @username = user['username'] if user
  
  # Get cart items with product details
  @cart_items = db.execute("
    SELECT ci.id, ci.quantity, p.id AS product_id, p.productname, p.price, p.image
    FROM cart_items ci
    JOIN productinfo p ON ci.product_id = p.id
    WHERE ci.user_id = ?", 
    [session[:id]]
  )
  
  # Calculate total
  @total = @cart_items.sum { |item| item['price'] * item['quantity'] }
  
  return slim(:cart)
end

# Add item to cart
post('/add_to_cart/:id') do

  product_id = params['id']
  quantity = params['quantity'] ? params['quantity'].to_i : 1
  
  db = connect_to_db('db/slutprojekt.db')
  
  # Check if item already in cart
  existing = db.get_first_row("
    SELECT id, quantity FROM cart_items 
    WHERE user_id = ? AND product_id = ?", 
    [session[:id], product_id]
  )
  
  if existing
    # Update quantity if already in cart
    new_quantity = existing['quantity'] + quantity
    db.execute("
      UPDATE cart_items SET quantity = ? 
      WHERE id = ?", 
      [new_quantity, existing['id']]
    )
  else
    # Add new cart item
    db.execute("
      INSERT INTO cart_items (user_id, product_id, quantity) 
      VALUES (?, ?, ?)", 
      [session[:id], product_id, quantity]
    )
  end
  
  notice("Product added to cart")
  redirect('/')
end

# Update cart item quantity
post('/update-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  quantity = params['quantity'].to_i
  
  db = connect_to_db('db/slutprojekt.db')
  
  if quantity <= 0
    # Remove item if quantity is zero or negative
    db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", 
      [cart_item_id, session[:id]]
    )
  else
    # Update quantity
    db.execute("UPDATE cart_items SET quantity = ? WHERE id = ? AND user_id = ?", 
      [quantity, cart_item_id, session[:id]]
    )
  end
  
  redirect '/shoppingcart'
end

# Remove item from cart
post('/remove-from-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  
  db = connect_to_db('db/slutprojekt.db')
  db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", 
    [cart_item_id, session[:id]]
  )
  
  redirect '/shoppingcart'
end