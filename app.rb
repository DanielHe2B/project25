require 'sinatra'
require 'slim'                # @note Template engine for views
require 'sqlite3'             # @note SQLite3 database connector
require 'sinatra/reloader'    # @note Auto-reload code during development
require 'bcrypt'              # @note Library for password hashing
require_relative './model.rb' # @note Imports model methods from external file
require 'sinatra/flash'       # @note Enables flash messages for notifications

enable :sessions             # @note Enables sessions for user authentication

include Model                # @note Includes methods from Model module

##
# @before_filter Checks authentication and authorization before processing routes.
# - Allows guest access to public routes
# - Requires login for private routes
# - Requires admin access for admin-specific routes
before do
  public_routes = ['/', '/showlogin', '/login', '/register', '/users', '/users/new']
  admin_routes = ['/accounts', '/product/new', '/products/create', '/product/edit']

  if request.request_method == "POST" && (request.path_info == "/users" || request.path_info == "/users/new")
    pass
  elsif !public_routes.include?(request.path_info) && !session[:id]
    notice("Unable to reach this site, try logging in")
    redirect('/showlogin')
  elsif admin_routes.any? { |route| request.path_info.start_with?(route) } ||
        (request.request_method == "POST" && 
         (request.path_info.include?('/product/') || 
          request.path_info.include?('/products/') || 
          request.path_info.start_with?('/user/')))
    unless is_admin?(session[:id])
      notice("Admin access required")
      redirect('/')
    end
  end
end

##
# @route GET /
# @return [Slim::Template] Renders the home page with product list
get('/') do
  @username = get_username(session[:id])
  @products = get_all_products()  
  slim(:index)
end

##
# @route GET /showlogin
# @return [Slim::Template] Renders the login form
get('/showlogin') do
  slim(:login)
end

##
# @route GET /register
# @return [Slim::Template] Renders the registration form
get('/register') do
  slim(:register)
end

##
# @route POST /login
# @param [String] username
# @param [String] password
# @return [Redirect] Redirects to home if login successful, else shows error
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
    redirect('/showlogin')
  end

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

##
# @route POST /users
# @return [Redirect] Redirects to home if registration is successful, else returns to register
post('/users') do
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

##
# @route GET /accounts
# @note Admin-only route
# @return [Slim::Template] Renders user account overview
get('/accounts') do 
  @users = get_all_users()
  @username = get_username(session[:id])
  slim(:show_accounts)
end

##
# @route POST /user/:id/delete
# @note Admin-only route
# @param [String] id - ID of user to delete
# @return [Redirect] Redirects to accounts page
post('/user/:id/delete') do 
  id = params['id']
  delete_user(id)
  notice("user successfully removed")
  redirect('/accounts')
end

##
# @route GET /logout
# @return [Redirect] Clears session and redirects to home
get('/logout') do
  session.clear
  notice("You have logged out")
  redirect('/')
end

##
# @route GET /product_new
# @note Admin-only route
# @return [Slim::Template] Renders product creation form
get('/product/new') do
  @username = get_username(session[:id])
  slim(:new)
end

##
# @route POST /products
# @note Admin-only route
# @return [Redirect] Redirects to home after creating product
post('/product') do
  @username = get_username(session[:id])
  productname = params['productname']
  description = params['description']
  price = params['price'].to_f
  image = params['image']
  
  create_product(productname, description, price, image)
  
  notice("Product successfully added")
  redirect('/')
end

##
# @route POST /product/:id/delete
# @note Admin-only route
# @return [Redirect] Deletes product and redirects to home
post('/product/:id/delete') do
  id = params['id']
  delete_product(id)
  
  notice("Product successfully removed")
  redirect('/')
end

##
# @route GET /product/edit/:id
# @note Admin-only route
# @return [Slim::Template] Renders product edit form
get('/product/:id/edit') do
  @username = get_username(session[:id])
  @id = params[:id]
  slim(:edit)
end

##
# @route POST /product/:id/update
# @note Admin-only route
# @return [Redirect] Updates product and redirects to home
post('/product/:id/update') do
  productname = params['new_productname']
  description = params['new_description']
  price = params['new_price'].to_f
  image = params['new_image']
  id = params['id']
  
  update_product(id, productname, description, price, image)
  
  notice("Productinfo successfully changed")
  redirect('/')
end

##
# @route GET /shoppingcart
# @return [Slim::Template] Shows shopping cart if logged in
get('/shoppingcart') do
  redirect '/showlogin' unless session[:id]
  
  @username = get_username(session[:id])
  @cart_items = get_cart_items(session[:id])
  @total = calculate_cart_total(@cart_items)
  
  slim(:cart)
end

##
# @route POST /add_to_cart/:id
# @param [String] id - Product ID
# @return [Redirect] Adds product to cart and redirects home
post('/add_to_cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  product_id = params['id']
  quantity = params['quantity'] ? params['quantity'].to_i : 1
  
  add_to_cart(session[:id], product_id, quantity)
  
  notice("Product added to cart")
  redirect('/')
end

##
# @route POST /update-cart/:id
# @param [String] id - Cart item ID
# @return [Redirect] Updates item quantity in cart
post('/update-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  quantity = params['quantity'].to_i
  
  update_cart_item(cart_item_id, session[:id], quantity)
  notice("Shopping cart successfully updated")
  redirect('/shoppingcart')
end

##
# @route POST /remove-from-cart/:id
# @param [String] id - Cart item ID
# @return [Redirect] Removes item from cart
post('/remove-from-cart/:id') do
  redirect '/showlogin' unless session[:id]
  
  cart_item_id = params['id']
  remove_from_cart(cart_item_id, session[:id])
  notice("Product sucessfully removed from shopping cart")
  redirect('/shoppingcart')
end
