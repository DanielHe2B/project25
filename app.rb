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
get('/') do
  @username = get_username(session[:id])
  @products = get_all_products()  
  return slim(:index)
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
  username = params[:username]
  password = params[:password]
  
  # Validate that form fields are not empty
  if username.empty? || password.empty?
    failed("Please put fill all the boxes")
    redirect('/showlogin')
  end

  # Check if the username exists and authenticate
  user_id = authenticate_user(username, password)
  
  if user_id
    session[:id] = user_id
    notice("Logged In")  
    redirect('/')
  else
    failed("Invalid username or password")
    redirect('/showlogin')
  end
end

# Route: Process registration form submission
post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  
  result = register_user(username, password, password_confirm)
  
  if result[:success]
    session[:id] = result[:user_id]
    redirect('/')
  else
    validera(result[:message])    
    redirect('/register')
  end
end

# Route: Show all user accounts (admin functionality)
get('/accounts') do 
  @users = get_all_users()
  @username = get_username(session[:id])
  return slim(:show_accounts)
end

# Route: Delete a user account (admin functionality)
post('/user/:id/delete') do 
  id = params['id']
  delete_user(id)
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
  @username = get_username(session[:id])
  return slim(:new)
end

# Route: Process new product form submission
post('/products/create') do
  @username = get_username(session[:id])
  
  # Get form data for new product
  productname = params['productname']
  description = params['description']
  price = params['price'].to_f
  image = params['image']
  
  # Create new product
  create_product(productname, description, price, image)
  
  notice("Product successfully added")
  redirect('/')
end

# Route: Delete a product (admin functionality)
post('/product/:id/delete') do
  id = params['id']
  delete_product(id)
  
  notice("Product successfully removed")
  redirect('/')
end

# Route: Show form to edit a product (admin functionality)
get('/product/edit/:id') do
  @username = get_username(session[:id])
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
  
  # Update product
  update_product(id, productname, description, price, image)
  
  notice("Productinfo successfully changed")
  redirect('/')
end

# Route: Show shopping cart for current user
get('/shoppingcart') do
  redirect '/showlogin' unless session[:id] #redirect to login if not logged in
  
  @username = get_username(session[:id])
  @cart_items = get_cart_items(session[:id])
  @total = calculate_cart_total(@cart_items)
  
  return slim(:cart)
end

# Route: Add item to shopping cart
post('/add_to_cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  product_id = params['id']
  quantity = params['quantity'] ? params['quantity'].to_i : 1
  
  add_to_cart(session[:id], product_id, quantity)
  
  notice("Product added to cart")
  redirect('/')
end

# Route: Update quantity of item in cart
post('/update-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  quantity = params['quantity'].to_i
  
  update_cart_item(cart_item_id, session[:id], quantity)
  notice("Shopping cart successfully updated")
  redirect('/shoppingcart')
end

# Route: Remove item from cart
post('/remove-from-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  remove_from_cart(cart_item_id, session[:id])
  notice("Product sucessfully removed from shopping cart")
  redirect('/shoppingcart')
end