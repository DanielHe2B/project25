require 'sinatra'
require 'slim'                
require 'sqlite3'           
require 'sinatra/reloader'    
require 'bcrypt'             
require_relative './model.rb'
require 'sinatra/flash'    

enable :sessions             

include Model             

# Before each request:
# - Allows guest access to public routes
# - Requires login for private routes
# - Requires admin access for admin-only routes
before do
  public_routes = ['/', '/login', '/register', '/users', '/users/new']
  admin_routes = ['/users', '/products/new', '/products/create', '/products/edit']

  if request.request_method == "POST" && (request.path_info == "/users" || request.path_info == "/users/new")
    pass
  elsif !public_routes.include?(request.path_info) && !session[:id]
    notice("Unable to reach this site, try logging in")
    redirect('/login')
  elsif admin_routes.any? { |route| request.path_info.start_with?(route) } ||
        (request.request_method == "POST" && 
         (request.path_info.include?('/products/') || 
          request.path_info.start_with?('/user/')))
    unless is_admin?(session[:id])
      notice("Admin access required")
      redirect('/')
    end
  end
end

# Display Home Page
#
# @see Model#get_username
# @see Model#get_all_products
get('/') do
  @username = get_username(session[:id])
  @products = get_all_products()  
  slim(:index)
end

# Display Login Form
#
get('/login') do
  slim(:login)
end

# Display Registration Form
#
get('/register') do
  slim(:register)
end

# Attempt to Login
#
# @param [String] username, the username
# @param [String] password, the passwornd
#
# @see Model#notice
# @see Model#failed
# @see Model#check_login_attempts
# @see Model#authenticate_user
post('/login') do
  username = params[:username]
  password = params[:password]

  if check_login_attempts(username)
    notice("Too many login attempts. Please wait before trying again.")
    redirect('/')
    return
  end

  if username.empty? || password.empty?
    failed("Please put fill all the boxes")
    redirect('/login')
  end

  user_id = authenticate_user(username, password)

  if user_id
    session[:id] = user_id
    notice("Logged In")  
    redirect('/')
  else
    failed("Invalid username or password")
    redirect('/login')
  end
end

# Register New User
#
# @param [String] username, the username
# @param [String] password, the password
# @param [String] password_confirm, the password
#
# @see Model#register_user
# @see Model#validera
post('/register') do
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

# Display All User Accounts (Admin-only)
#
# @see Model#get_all_users
# @see Model#get_username
get('/users') do 
  @users = get_all_users()
  @username = get_username(session[:id])
  slim(:show_users)
end

# Delete a User (Admin-only)
#
# @param [Integer] id, User ID
#
# @see Model#delete_user
# @see Model#notice
post('/users/:id/delete') do 
  id = params['id']
  delete_user(id)
  notice("user successfully removed")
  redirect('/accounts')
end

# Logout User
#
# @see Model#notice
get('/logout') do
  session.clear
  notice("You have logged out")
  redirect('/')
end

# Display New Product Form (Admin-only)
#
# @see Model#get_username
get('/products/new') do
  @username = get_username(session[:id])
  slim(:new)
end

# Create New Product (Admin-only)
#
# @param [String] productname, name of the new product
# @param [String] description, the description
# @param [Float] price, the price
# @param [String] image, the image URL
#
# @see Model#get_username
# @see Model#create_product
# @see Model#notice
post('/products') do
  @username = get_username(session[:id])
  productname = params['productname']
  description = params['description']
  price = params['price'].to_f
  image = params['image']
  
  create_product(productname, description, price, image)
  
  notice("Product successfully added")
  redirect('/')
end

# Delete a Product (Admin-only)
#
# @param [Integer] id, Product ID
#
# @see Model#delete_product
# @see Model#notice
post('/products/:id/delete') do
  id = params['id']
  delete_product(id)
  
  notice("Product successfully removed")
  redirect('/')
end

# Display Edit Product Form (Admin-only)
#
# @param [Integer] id, Product ID
#
# @see Model#get_username
get('/products/:id/edit') do
  @username = get_username(session[:id])
  @id = params[:id]
  slim(:edit)
end

# Update a Product (Admin-only)
#
# @param [Integer] id, the ID of the product to update
# @param [String] new_productname, the updated name of the product
# @param [String] new_description, the updated description of the product
# @param [Float] new_price, the updated price of the product
# @param [String] new_image, the updated URL or path to the product image
#
# @see Model#update_product
# @see Model#notice
post('/products/:id/update') do
  productname = params['new_productname']
  description = params['new_description']
  price = params['new_price'].to_f
  image = params['new_image']
  id = params['id']
  
  update_product(id, productname, description, price, image)
  
  notice("Productinfo successfully changed")
  redirect('/')
end

# Display Shopping Cart
#
# @see Model#get_username
# @see Model#get_cart_items
# @see Model#calculate_cart_total
get('/carts') do
  redirect '/showlogin' unless session[:id]
  
  @username = get_username(session[:id])
  @cart_items = get_cart_items(session[:id])
  @total = calculate_cart_total(@cart_items)
  
  slim(:show_cart)
end

# Add Product to Cart
#
# @param [Integer] id, Product ID
# @param [Integer] quantity, Quantity of the product
#
# @see Model#add_to_cart
# @see Model#notice
post('/carts/:id') do
  redirect '/login' unless session[:id]
  
  product_id = params['id']
  quantity = params['quantity'] ? params['quantity'].to_i : 1
  
  add_to_cart(session[:id], product_id, quantity)
  
  notice("Product added to cart")
  redirect('/')
end

# Update Quantity in Cart
#
# @param [Integer] id, Cart item ID
# @param [Integer] quantity, Quantity of a product
#
# @see Model#update_cart_item
# @see Model#notice
# @see Model#failed
post('/carts/:id/update') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  quantity = params['quantity'].to_i
  
  if update_cart_item(cart_item_id, session[:id], quantity)
    notice("Shopping cart successfully updated")
  else
    failed("You do not have permission to update this item")
  end
  redirect('/carts')
end

# Remove Item from Cart
#
# @param [Integer] id, Cart item ID
#
# @see Model#remove_from_cart
# @see Model#notice
# @see Model#failed
post('/carts/:id/delete') do
  redirect '/login' unless session[:id]
  
  cart_item_id = params['id']
  if remove_from_cart(cart_item_id, session[:id])
    notice("Product successfully removed from shopping cart")
  else
    failed("You do not have permission to remove this item")
  end
  redirect('/carts')
end
