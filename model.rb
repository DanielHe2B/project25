module Model
  ##
  # Connects to the SQLite3 database.
  #
  # @param db_path [String] Path to the database file
  # @return [SQLite3::Database] Database connection object
  def connect_to_db(db_path)
    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    return db
  end

  ##
  # Retrieves the current user from session ID.
  #
  # @param session_id [Integer, nil] The ID from the session
  # @return [Hash, nil] User record or nil if not found
  def get_current_user(session_id)
    return nil unless session_id
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT * FROM users WHERE id = ?", session_id).first
    return user
  end

  ##
  # Gets the username of the current session user.
  #
  # @param session_id [Integer, nil]
  # @return [String, nil] Username or nil if not found
  def get_username(session_id)
    user = get_current_user(session_id)
    return user ? user['username'] : nil
  end

  ##
  # Checks if the user is an admin.
  #
  # @param session_id [Integer, nil]
  # @return [Boolean] True if admin, otherwise false
  def is_admin?(session_id)
    return false unless session_id
    user = get_current_user(session_id)
    return user && user['username'].downcase == 'admin'
  end

  ##
  # Checks if a user is logged in.
  #
  # @param session_id [Integer, nil]
  # @return [Boolean]
  def is_logged_in?(session_id)
    return !session_id.nil?
  end

  ##
  # Sets a success flash message.
  #
  # @param message [String]
  def notice(message)
    flash[:notice] = message
  end

  ##
  # Sets a failure flash message.
  #
  # @param message [String]
  def failed(message)
    flash[:fail] =  message
  end

  ##
  # Sets a validation flash message.
  #
  # @param message [String]
  def validera(message)
    flash[:validate] = message
  end

  ##
  # Checks if a user exists by username.
  #
  # @param username [String]
  # @return [Boolean]
  def user_exists?(username)
    db = connect_to_db('db/slutprojekt.db')
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    return !result.nil?
  end

  ##
  # Creates a new user.
  #
  # @param username [String]
  # @param password [String]
  # @return [Integer, false] Returns user ID or false if creation failed
  def create_user(username, password)
    return false if username.empty? || password.empty?
    return false if user_exists?(username)

    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?,?)", [username, password_digest])
    return db.last_insert_row_id
  end

  ##
  # Records a failed login attempt.
  #
  # @param username [String]
  def record_failed_login(username)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO login_attempts (username, timestamp) VALUES (?, ?)", [username, Time.now.to_i])
  end

  ##
  # Checks if login attempts exceed limit.
  #
  # @param username [String]
  # @return [Boolean] True if over limit, else false
  def check_login_attempts(username)
    db = connect_to_db('db/slutprojekt.db')
    time_limit = Time.now.to_i - 60
    attempts = db.execute("SELECT COUNT(*) AS count FROM login_attempts WHERE username = ? AND timestamp > ?", [username, time_limit]).first["count"]
    return attempts >= 5
  end

  ##
  # Authenticates a user by credentials.
  #
  # @param username [String]
  # @param password [String]
  # @return [Integer, nil] User ID if success, nil if fail
  def authenticate_user(username, password)
    return nil if username.empty? || password.empty?

    db = connect_to_db('db/slutprojekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    return nil unless result

    if BCrypt::Password.new(result["passwordDigest"]) == password
      return result["id"]
    else
      record_failed_login(username)
      return nil
    end
  end

  ##
  # Deletes a user and associated cart items.
  #
  # @param id [Integer] User ID
  def delete_user(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM users WHERE id = ?", [id])
    db.execute("DELETE FROM cart_items WHERE user_id = ?", [id])
  end

  ##
  # Retrieves all users.
  #
  # @return [Array<Hash>] All user records
  def get_all_users
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM users")
  end

  ##
  # Retrieves all products.
  #
  # @return [Array<Hash>]
  def get_all_products
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM productinfo")
  end

  ##
  # Retrieves a product by ID.
  #
  # @param id [Integer]
  # @return [Hash, nil]
  def get_product(id)
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM productinfo WHERE id = ?", id).first
  end

  ##
  # Creates a new product.
  #
  # @param productname [String]
  # @param description [String]
  # @param price [Float]
  # @param image [String]
  # @return [Integer] New product ID
  def create_product(productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO productinfo (productname, price, description, image) VALUES (?, ?, ?, ?)", 
               [productname, price, description, image])
    return db.last_insert_row_id
  end

  ##
  # Updates an existing product.
  #
  # @param id [Integer]
  # @param productname [String]
  # @param description [String]
  # @param price [Float]
  # @param image [String]
  def update_product(id, productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("UPDATE productinfo SET productname = ?, price = ?, description = ?, image = ? WHERE id = ?",
               [productname, price, description, image, id])
  end

  ##
  # Deletes a product.
  #
  # @param id [Integer]
  def delete_product(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM productinfo WHERE id = ?", [id])
  end

  ##
  # Retrieves all items in the user's cart.
  #
  # @param user_id [Integer]
  # @return [Array<Hash>]
  def get_cart_items(user_id)
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("
      SELECT ci.id, ci.quantity, p.id AS product_id, p.productname, p.price, p.image
      FROM cart_items ci
      JOIN productinfo p ON ci.product_id = p.id
      WHERE ci.user_id = ?", 
      [user_id]
    )
  end

  ##
  # Adds an item to the shopping cart.
  #
  # @param user_id [Integer]
  # @param product_id [Integer]
  # @param quantity [Integer] (default: 1)
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

  ##
  # Updates the quantity of an item in the cart.
  #
  # @param cart_item_id [Integer]
  # @param user_id [Integer]
  # @param quantity [Integer]
  def update_cart_item(cart_item_id, user_id, quantity)
    db = connect_to_db('db/slutprojekt.db')
    if quantity <= 0
      remove_from_cart(cart_item_id, user_id)
    else
      db.execute("UPDATE cart_items SET quantity = ? WHERE id = ? AND user_id = ?", [quantity, cart_item_id, user_id])
    end
  end

  ##
  # Removes an item from the cart.
  #
  # @param cart_item_id [Integer]
  # @param user_id [Integer]
  def remove_from_cart(cart_item_id, user_id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", [cart_item_id, user_id])
  end

  ##
  # Calculates the total value of the shopping cart.
  #
  # @param cart_items [Array<Hash>]
  # @return [Integer] Total price
  def calculate_cart_total(cart_items)
    cart_items.sum { |item| item['price'].to_i * item['quantity'] }
  end

  ##
  # Registers a new user after validating input.
  #
  # @param username [String]
  # @param password [String]
  # @param password_confirm [String]
  # @return [Hash] Success status and message or user_id
  def register_user(username, password, password_confirm)
    return { success: false, message: "Username was taken" } if user_exists?(username)

    if username.empty? || password.empty? || password_confirm.empty?
      return { success: false, message: "Please fill all the boxes" }
    elsif password != password_confirm
      return { success: false, message: "Please confirm the password" }
    end

    user_id = create_user(username, password)
    if user_id
      return { success: true, user_id: user_id }
    else
      return { success: false, message: "Failed to create user" }
    end
  end
end