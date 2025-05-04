module Model
  
  # Connects to the SQLite3 database.
  #
  # @param db_path [String] the path to the database file
  # @return [SQLite3::Database] the database connection object
  def connect_to_db(db_path)
    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    db
  end

  # Retrieves the current user based on session ID.
  #
  # @param session_id [Integer, nil] the ID stored in the session
  # @return [Hash, nil] the user record or nil if not found
  def get_current_user(session_id)
    return nil unless session_id

    db = connect_to_db('db/slutprojekt.db')
    db.execute("SELECT * FROM users WHERE id = ?", session_id).first
  end

  # Retrieves the username of the currently logged-in user.
  #
  # @param session_id [Integer, nil] the ID stored in the session
  # @return [String, nil] the username or nil if not found
  def get_username(session_id)
    user = get_current_user(session_id)
    user ? user['username'] : nil
  end

  # Checks whether the current user is an admin.
  #
  # @param session_id [Integer, nil] the ID stored in the session
  # @return [Boolean] true if the user is an admin, false otherwise
  def is_admin?(session_id)
    return false unless session_id

    user = get_current_user(session_id)
    user && user['username'].downcase == 'admin'
  end

  # Checks whether a user is logged in.
  #
  # @param session_id [Integer, nil] the ID stored in the session
  # @return [Boolean] true if logged in, false otherwise
  def is_logged_in?(session_id)
    !session_id.nil?
  end

  # Sets a success flash message.
  #
  # @param message [String] the message to display
  def notice(message)
    flash[:notice] = message
  end

  # Sets a failure flash message.
  #
  # @param message [String] the message to display
  def failed(message)
    flash[:fail] = message
  end

  # Sets a validation flash message.
  #
  # @param message [String] the message to display
  def validera(message)
    flash[:validate] = message
  end

  # Checks if a user with the given username already exists.
  #
  # @param username [String] the username to check
  # @return [Boolean] true if user exists, false otherwise
  def user_exists?(username)
    db = connect_to_db('db/slutprojekt.db')
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    !result.nil?
  end

  # Creates a new user.
  #
  # @param username [String] the desired username
  # @param password [String] the user's password
  # @return [Integer, false] the new user's ID if created, or false on failure
  def create_user(username, password)
    return false if username.empty? || password.empty?
    return false if user_exists?(username)

    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?, ?)", [username, password_digest])
    db.last_insert_row_id
  end

  # Records a failed login attempt.
  #
  # @param username [String] the username used in the failed attempt
  def record_failed_login(username)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO login_attempts (username, timestamp) VALUES (?, ?)", [username, Time.now.to_i])
  end

  # Checks if login attempts have exceeded the limit.
  #
  # @param username [String] the username to check
  # @return [Boolean] true if login attempts exceed the allowed limit
  def check_login_attempts(username)
    db = connect_to_db('db/slutprojekt.db')
    time_limit = Time.now.to_i - 60
    attempts = db.execute("SELECT COUNT(*) AS count FROM login_attempts WHERE username = ? AND timestamp > ?", [username, time_limit]).first["count"]
    attempts >= 5
  end

  # Authenticates a user based on credentials.
  #
  # @param username [String] the username
  # @param password [String] the password
  # @return [Integer, nil] the user ID if authentication succeeds, otherwise nil
  def authenticate_user(username, password)
    return nil if username.empty? || password.empty?

    db = connect_to_db('db/slutprojekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    return nil unless result

    if BCrypt::Password.new(result["passwordDigest"]) == password
      result["id"]
    else
      record_failed_login(username)
      nil
    end
  end

  # Deletes a user and their cart items.
  #
  # @param id [Integer] the ID of the user to delete
  def delete_user(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM users WHERE id = ?", [id])
    db.execute("DELETE FROM cart_items WHERE user_id = ?", [id])
  end

  # Retrieves all users.
  #
  # @return [Array<Hash>] an array of user records
  def get_all_users
    db = connect_to_db('db/slutprojekt.db')
    db.execute("SELECT * FROM users")
  end

  # Retrieves all products.
  #
  # @return [Array<Hash>] an array of product records
  def get_all_products
    db = connect_to_db('db/slutprojekt.db')
    db.execute("SELECT * FROM productinfo")
  end

  # Retrieves a single product by ID.
  #
  # @param id [Integer] the product ID
  # @return [Hash, nil] the product record or nil if not found
  def get_product(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("SELECT * FROM productinfo WHERE id = ?", id).first
  end

  # Creates a new product.
  #
  # @param productname [String] the name of the product
  # @param description [String] the product description
  # @param price [Float] the product price
  # @param image [String] the product image URL or path
  # @return [Integer] the new product ID
  def create_product(productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO productinfo (productname, price, description, image) VALUES (?, ?, ?, ?)",
               [productname, price, description, image])
    db.last_insert_row_id
  end

  # Updates an existing product.
  #
  # @param id [Integer] the product ID
  # @param productname [String] the updated product name
  # @param description [String] the updated product description
  # @param price [Float] the updated price
  # @param image [String] the updated product image
  def update_product(id, productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("UPDATE productinfo SET productname = ?, price = ?, description = ?, image = ? WHERE id = ?",
               [productname, price, description, image, id])
  end

  # Deletes a product by ID.
  #
  # @param id [Integer] the product ID
  def delete_product(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM productinfo WHERE id = ?", [id])
  end

  # Retrieves all items in a user's shopping cart.
  #
  # @param user_id [Integer] the user's ID
  # @return [Array<Hash>] the cart items with associated product data
  def get_cart_items(user_id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("
      SELECT ci.id, ci.quantity, p.id AS product_id, p.productname, p.price, p.image
      FROM cart_items ci
      JOIN productinfo p ON ci.product_id = p.id
      WHERE ci.user_id = ?",
      [user_id]
    )
  end

  # Adds an item to the shopping cart.
  #
  # @param user_id [Integer] the user's ID
  # @param product_id [Integer] the product ID
  # @param quantity [Integer] the quantity to add (default: 1)
  def add_to_cart(user_id, product_id, quantity = 1)
    db = connect_to_db('db/slutprojekt.db')
    existing = db.get_first_row("SELECT id, quantity FROM cart_items WHERE user_id = ? AND product_id = ?", [user_id, product_id])

    if existing
      new_quantity = existing['quantity'] + quantity
      db.execute("UPDATE cart_items SET quantity = ? WHERE id = ?", [new_quantity, existing['id']])
    else
      db.execute("INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)", [user_id, product_id, quantity])
    end
  end

  # Updates the quantity of a cart item.
  #
  # @param cart_item_id [Integer] the cart item ID
  # @param user_id [Integer] the user's ID
  # @param quantity [Integer] the new quantity
  def update_cart_item(cart_item_id, user_id, quantity)
    db = connect_to_db('db/slutprojekt.db')
    if quantity <= 0
      remove_from_cart(cart_item_id, user_id)
    else
      db.execute("UPDATE cart_items SET quantity = ? WHERE id = ? AND user_id = ?", [quantity, cart_item_id, user_id])
    end
  end

  # Removes an item from the cart.
  #
  # @param cart_item_id [Integer] the cart item ID
  # @param user_id [Integer] the user's ID
  def remove_from_cart(cart_item_id, user_id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", [cart_item_id, user_id])
  end

  # Calculates the total cost of the shopping cart.
  #
  # @param cart_items [Array<Hash>] the items in the cart
  # @return [Integer] the total price
  def calculate_cart_total(cart_items)
    cart_items.sum { |item| item['price'].to_i * item['quantity'] }
  end

  # Registers a new user after validating input.
  #
  # @param username [String] the desired username
  # @param password [String] the password
  # @param password_confirm [String] the password confirmation
  # @return [Hash] a hash indicating success or failure and a message or user ID
  def register_user(username, password, password_confirm)
    return { success: false, message: "Username was taken" } if user_exists?(username)

    if username.empty? || password.empty? || password_confirm.empty?
      return { success: false, message: "Please fill all the boxes" }
    elsif password != password_confirm
      return { success: false, message: "Please confirm the password" }
    end

    user_id = create_user(username, password)
    if user_id
      { success: true, user_id: user_id }
    else
      { success: false, message: "Failed to create user" }
    end
  end
end
