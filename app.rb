require 'sinatra'
require 'slim'                # Template engine for views
require 'sqlite3'             # Database connector
require 'sinatra/reloader'    # Auto-reload code during development
require 'bcrypt'              # Password hashing library for security
require_relative './model.rb' # Import models from separate file
require 'sinatra/flash'       # Flash messages for user notifications

enable :sessions             # Enable session support for user authentication

include Model                # Include model methods from model.rb

# Route: Home page
get('/') do #visar hemsidan (Swedish: shows the homepage)
    # If user is logged in, get their username
    if session[:id]
      db = connect_to_db('db/slutprojekt.db')
      user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
      @username = user['username'] if user
    end

    # Get all products to display on homepage
    db = connect_to_db('db/slutprojekt.db')
    @products = db.execute("SELECT * FROM productinfo")  
    return slim(:show)
end

# Route: Show login form
get('/showlogin') do
    return slim(:login)
end

# Route: Show registration form
get('/register') do
    return slim(:register)
end

# Route: Process login form submission
post('/login') do
    username=params[:username]
    password=params[:password]
    
    # Validate that form fields are not empty
    if username.empty? || password.empty?
      failed("Please put fill all the boxes")
      redirect('/showlogin')
    end

    # Check if the username exists in database
    db = connect_to_db('db/slutprojekt.db')
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    if !result
      failed("Username does not exist")
      redirect('/showlogin')
    end

    # Get user information from database
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    passwordDigest = result["passwordDigest"] 
    id = result["id"]

    # Verify password using BCrypt
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

# Route: Process registration form submission
post('/users/new') do
  username=params[:username]
  password=params[:password]
  password_confirm=params[:password_confirm]
  db = connect_to_db('db/slutprojekt.db')

  # Check if username already exists
  result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)

  if result
    validera("Username was taken")    
    redirect('/register')    
  end

  # Validate form data
  if (password==password_confirm) and ((password!="") and (password_confirm!="") and username!="")
    # Create password hash and insert new user
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

# Route: Show all user accounts (admin functionality)
get('/accounts') do 
  db = connect_to_db('db/slutprojekt.db')
  @users = db.execute("SELECT * FROM users")
  if session[:id]
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
    @username = user['username'] if user
  end
  return slim(:show_accounts)
end

# Route: Delete a user account (admin functionality)
post('/user/:id/delete') do 
  id = params['id']
  
  # Delete the user from database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("DELETE FROM users WHERE id = ?", [id])
  
  notice("user successfully removed")
  redirect('/accounts')
end

# Route: Log out user by clearing session
get('/logout') do
  session.clear
  notice("You have logged out")
  redirect('/')
end

# Route: Show form to add new product (admin functionality)
get('/product_new') do
  if session[:id]
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
    @username = user['username'] if user
  end
  return slim(:new)
end

# Route: Process new product form submission
post('/products/create') do
  # Note: Admin check is commented out
  #p @username.to_s.downcase
  #redirect '/' unless @username.to_s.downcase == "admin"
  
  # Get current user information
  if session[:id]
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
    @username = user['username'] if user
  end
  
  # Get form data for new product
  productname = params['productname']
  description = params['description']
  price = params['price'].to_f
  image = params['image']
  
  # Insert new product into database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("INSERT INTO productinfo (productname, price, description, image) VALUES (?, ?, ?, ?)", [productname, price, description, image])
  
  notice("Product successfully added")
  redirect('/')
end

# Route: Delete a product (admin functionality)
post('/product/:id/delete') do
  # Note: Admin check is commented out
  #redirect '/login' unless session[:user_id]
  
  id = params['id']
  
  # Delete the product from database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("DELETE FROM productinfo WHERE id = ?", [id])
  
  notice("Product successfully removed")
  redirect('/')
end

# Route: Show form to edit a product (admin functionality)
get('/product/edit/:id') do
  if session[:id]
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
    @username = user['username'] if user
  end
  @id = params[:id]
  return slim(:edit)
end

# Route: Process product edit form submission
post('/product/:id/update') do
  # Get form data for product update
  productname = params['new_productname']
  description = params['new_description']
  price = params['new_price'].to_f
  image = params['new_image']
  id = params['id']
  p [productname, price, description, image, id] # Debug print
  
  # Update product in database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("UPDATE productinfo SET productname = ?, price = ?, description = ?, image = ? WHERE id = ?",
    [productname, price, description, image, id])  
  notice("Productinfo successfully changed")
  redirect('/')
end

# Route: Show shopping cart for current user
get('/shoppingcart') do
  # Check if user is logged in and get username
  if session[:id]
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
    @username = user['username'] if user
  end
  
  db = connect_to_db('db/slutprojekt.db')
  user = db.execute("SELECT username FROM users WHERE id = ?", session[:id]).first
  @username = user['username'] if user
  
  # Get cart items with product details through SQL join
  @cart_items = db.execute("
    SELECT ci.id, ci.quantity, p.id AS product_id, p.productname, p.price, p.image
    FROM cart_items ci
    JOIN productinfo p ON ci.product_id = p.id
    WHERE ci.user_id = ?", 
    [session[:id]]
  )
  
  # Calculate total price of all items in cart
  @total = @cart_items.sum { |item| item['price'].to_i * item['quantity'] }
  
  return slim(:cart)
end

# Route: Add item to shopping cart
post('/add_to_cart/:id') do
  # Get product ID and quantity from form
  product_id = params['id']
  quantity = params['quantity'] ? params['quantity'].to_i : 1
  
  db = connect_to_db('db/slutprojekt.db')
  
  # Check if item already exists in user's cart
  existing = db.get_first_row("
    SELECT id, quantity FROM cart_items 
    WHERE user_id = ? AND product_id = ?", 
    [session[:id], product_id]
  )
  
  if existing
    # Update quantity if item already in cart
    new_quantity = existing['quantity'] + quantity
    db.execute("
      UPDATE cart_items SET quantity = ? 
      WHERE id = ?", 
      [new_quantity, existing['id']]
    )
  else
    # Add new cart item if not already in cart
    db.execute("
      INSERT INTO cart_items (user_id, product_id, quantity) 
      VALUES (?, ?, ?)", 
      [session[:id], product_id, quantity]
    )
  end
  
  notice("Product added to cart")
  redirect('/')
end

# Route: Update quantity of item in cart
post('/update-cart/:id') do
  # Redirect to login if not logged in
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
    # Update quantity in database
    db.execute("UPDATE cart_items SET quantity = ? WHERE id = ? AND user_id = ?", 
      [quantity, cart_item_id, session[:id]]
    )
  end
  
  redirect '/shoppingcart'
end

# Route: Remove item from cart
post('/remove-from-cart/:id') do
  # Redirect to login if not logged in
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  
  # Delete cart item from database
  db = connect_to_db('db/slutprojekt.db')
  db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", 
    [cart_item_id, session[:id]]
  )
  
  redirect '/shoppingcart'
end