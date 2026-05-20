const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Sequelize, DataTypes, Op } = require('sequelize');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// ---------- Database Connection ----------
const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASSWORD,
  {
    host: process.env.DB_HOST,
    dialect: 'mysql',
    logging: false,
  }
);

sequelize.authenticate()
  .then(() => console.log('✅ Database connected'))
  .catch((err) => console.error('❌ Database connection error:', err));

// ---------- User Model (with role) ----------
const User = sequelize.define('User', {
  username: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: false,
  },
  email: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: false,
  },
  phone: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: true,
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  role: {
    type: DataTypes.ENUM('customer', 'seller', 'admin'),
    defaultValue: 'customer',
    allowNull: false,
  },
});

// ---------- Package Model ----------
const Package = sequelize.define('Package', {
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  price: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  dataSize: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  validity: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  createdBy: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },
}, {
  timestamps: true,
});

// ---------- Middleware ----------
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, message: 'Access denied.' });
  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ success: false, message: 'Invalid token.' });
    req.user = user;
    next();
  });
}

async function isSeller(req, res, next) {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user || user.role !== 'seller') {
      return res.status(403).json({ success: false, message: 'Sellers only.' });
    }
    next();
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
}

// ---------- Health Check ----------
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'WINGA PRO backend running' });
});

// ---------- Register Endpoint (accepts optional role) ----------
app.post('/api/register', async (req, res) => {
  try {
    const { username, email, phone, password, role } = req.body;

    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username, email and password are required',
      });
    }

    const existingUser = await User.findOne({
      where: {
        [Op.or]: [
          { username },
          { email },
          { phone: phone || null }
        ]
      }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with that username, email, or phone',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userRole = (role === 'seller') ? 'seller' : 'customer';

    await User.create({
      username,
      email,
      phone: phone || null,
      password: hashedPassword,
      role: userRole,
    });

    res.json({ success: true, message: 'User registered successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---------- Login Endpoint (returns token valid for 30 days) ----------
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username/email/phone and password are required',
      });
    }

    const user = await User.findOne({
      where: {
        [Op.or]: [
          { username: username },
          { email: username },
          { phone: username }
        ]
      }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Token expires in 30 days – users stay logged in for a long time
    const token = jwt.sign(
      { id: user.id, username: user.username, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      success: false,
      message: 'Server error during login',
    });
  }
});

// ---------- Package Endpoints ----------

// GET all packages (public)
app.get('/api/packages', async (req, res) => {
  try {
    const packages = await Package.findAll({
      order: [['createdAt', 'DESC']],
    });
    res.json(packages);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREATE a new package (sellers only)
app.post('/api/packages', authenticateToken, isSeller, async (req, res) => {
  try {
    const { name, price, dataSize, validity } = req.body;
    if (!name || !price || !dataSize || !validity) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const newPackage = await Package.create({
      name,
      price,
      dataSize,
      validity,
      createdBy: req.user.id,
    });

    res.status(201).json({ success: true, package: newPackage });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// UPDATE a package (sellers only)
app.put('/api/packages/:id', authenticateToken, isSeller, async (req, res) => {
  try {
    const pkg = await Package.findByPk(req.params.id);
    if (!pkg) {
      return res.status(404).json({ success: false, message: 'Package not found' });
    }

    const { name, price, dataSize, validity } = req.body;
    if (name) pkg.name = name;
    if (price) pkg.price = price;
    if (dataSize) pkg.dataSize = dataSize;
    if (validity) pkg.validity = validity;
    await pkg.save();

    res.json({ success: true, package: pkg });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE a package (sellers only)
app.delete('/api/packages/:id', authenticateToken, isSeller, async (req, res) => {
  try {
    const deleted = await Package.destroy({ where: { id: req.params.id } });
    if (deleted === 0) {
      return res.status(404).json({ success: false, message: 'Package not found' });
    }
    res.json({ success: true, message: 'Package deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Sync Database and Start Server ----------
const PORT = process.env.PORT || 5000;

sequelize.sync({ alter: true })
  .then(() => {
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 API available at http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('❌ Failed to sync database:', err);
  });