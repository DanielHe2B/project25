module Model
  # Database connection helpers
  def connect_to_db(db_path)
    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true
    return db
  end

  # Session and user helpers
  def get_current_user(session_id)
    return nil unless session_id
    db = connect_to_db('db/slutprojekt.db')
    user = db.execute("SELECT * FROM users WHERE id = ?", session_id).first
    return user
  end

  def get_username(session_id)
    user = get_current_user(session_id)
    return user ? user['username'] : nil
  end
    
  def is_logged_in?(session_id)
    return !session_id.nil?
  end

  # Flash message helpers
  def notice(message)
    flash[:notice] = message
  end

  def failed(message)
    flash[:fail] =  message
  end

  def validera(message)
    flash[:validate] = message
  end

  # User management
  def user_exists?(username)
    db = connect_to_db('db/slutprojekt.db')
    result = db.get_first_row("SELECT username FROM users WHERE username = ?", username)
    return !result.nil?
  end

  def create_user(username, password)
    # Validate inputs
    return false if username.empty? || password.empty?
    return false if user_exists?(username)
    
    # Create password hash and insert new user
    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?,?)", [username, password_digest])
    return db.last_insert_row_id
  end

  def authenticate_user(username, password)
    # Validate inputs
    return nil if username.empty? || password.empty?
    
    db = connect_to_db('db/slutprojekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    return nil unless result
    
    if BCrypt::Password.new(result["passwordDigest"]) == password
      return result["id"]
    else
      return nil
    end
  end

  def delete_user(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM users WHERE id = ?", [id])
  end

  def get_all_users
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM users")
  end

  # Product management
  def get_all_products
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM productinfo")
  end
  
  def get_product(id)
    db = connect_to_db('db/slutprojekt.db')
    return db.execute("SELECT * FROM productinfo WHERE id = ?", id).first
  end

  def create_product(productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO productinfo (productname, price, description, image) VALUES (?, ?, ?, ?)", 
               [productname, price, description, image])
    return db.last_insert_row_id
  end

  def update_product(id, productname, description, price, image)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("UPDATE productinfo SET productname = ?, price = ?, description = ?, image = ? WHERE id = ?",
               [productname, price, description, image, id])
  end

  def delete_product(id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM productinfo WHERE id = ?", [id])
  end

  # Shopping cart management
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

  def add_to_cart(user_id, product_id, quantity = 1)
    db = connect_to_db('db/slutprojekt.db')
    
    # Check if item already in cart
    existing = db.get_first_row("
      SELECT id, quantity FROM cart_items 
      WHERE user_id = ? AND product_id = ?", 
      [user_id, product_id]
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
        [user_id, product_id, quantity]
      )
    end
  end

  def update_cart_item(cart_item_id, user_id, quantity)
    db = connect_to_db('db/slutprojekt.db')
    
    if quantity <= 0
      # Remove item if quantity is zero or negative
      remove_from_cart(cart_item_id, user_id)
    else
      # Update quantity
      db.execute("UPDATE cart_items SET quantity = ? WHERE id = ? AND user_id = ?", 
        [quantity, cart_item_id, user_id]
      )
    end
  end

  def remove_from_cart(cart_item_id, user_id)
    db = connect_to_db('db/slutprojekt.db')
    db.execute("DELETE FROM cart_items WHERE id = ? AND user_id = ?", 
      [cart_item_id, user_id]
    )
  end

  def calculate_cart_total(cart_items)
    cart_items.sum { |item| item['price'].to_i * item['quantity'] }
  end
  
  # Registration logic
  def register_user(username, password, password_confirm)
    # Validate inputs
    return { success: false, message: "Username was taken" } if user_exists?(username)
    
    # Validate form data
    if username.empty? || password.empty? || password_confirm.empty?
      return { success: false, message: "Please fill all the boxes" }
    elsif password != password_confirm
      return { success: false, message: "Please confirm the password" }
    end
    
    # Create user if validation passes
    user_id = create_user(username, password)
    if user_id
      return { success: true, user_id: user_id }
    else
      return { success: false, message: "Failed to create user" }
    end
  end
end