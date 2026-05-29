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

// ---------- Database Connection (supports Railway internal + external proxy) ----------
let sequelize;

// 1. If Railway provides MYSQL_URL (internal or external), use it first
if (process.env.MYSQL_URL) {
  sequelize = new Sequelize(process.env.MYSQL_URL, {
    dialect: 'mysql',
    logging: false,
    dialectOptions: {
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
      connectTimeout: 60000
    }
  });
}
// 2. If explicit external proxy URL is provided (recommended for your setup)
else if (process.env.EXTERNAL_MYSQL_URL) {
  sequelize = new Sequelize(process.env.EXTERNAL_MYSQL_URL, {
    dialect: 'mysql',
    logging: false,
    dialectOptions: {
      ssl: { rejectUnauthorized: false },   // required for external proxy
      connectTimeout: 60000
    }
  });
}
// 3. Fallback to individual Railway variables (MYSQLHOST, etc.)
else if (process.env.MYSQLHOST) {
  sequelize = new Sequelize(
    process.env.MYSQLDATABASE,
    process.env.MYSQLUSER,
    process.env.MYSQLPASSWORD,
    {
      host: process.env.MYSQLHOST,
      port: process.env.MYSQLPORT || 3306,
      dialect: 'mysql',
      logging: false,
      dialectOptions: {
        connectTimeout: 60000
      }
    }
  );
}
// 4. Direct hardcoded external proxy (using your credentials) – only as last resort
else {
  console.log('⚠️ Using hardcoded external proxy (zephyr.proxy.rlwy.net:46065)');
  sequelize = new Sequelize('wingapro_db', 'root', 'kvhvfgfnDfrCnziRdjjVoSoTcoAQmbOK', {
    host: 'zephyr.proxy.rlwy.net',
    port: 46065,
    dialect: 'mysql',
    logging: false,
    dialectOptions: {
      ssl: { rejectUnauthorized: false },   // mandatory for external proxy
      connectTimeout: 60000
    }
  });
}

// ---------- Models ----------
const User = sequelize.define('User', {
  username: { type: DataTypes.STRING, unique: true, allowNull: false },
  email: { type: DataTypes.STRING, unique: true, allowNull: false },
  phone: { type: DataTypes.STRING, unique: true, allowNull: true },
  password: { type: DataTypes.STRING, allowNull: false },
  role: { type: DataTypes.ENUM('customer', 'seller', 'admin'), defaultValue: 'customer', allowNull: false },
  wallet_balance: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00, allowNull: false },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true, allowNull: false }
});

const Package = sequelize.define('Package', {
  name: { type: DataTypes.STRING, allowNull: false },
  price: { type: DataTypes.STRING, allowNull: false },
  dataSize: { type: DataTypes.STRING, allowNull: false },
  validity: { type: DataTypes.STRING, allowNull: false },
  createdBy: { type: DataTypes.INTEGER, allowNull: false, references: { model: User, key: 'id' } },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true, allowNull: false }
}, { timestamps: true });

const Transaction = sequelize.define('Transaction', {
  buyer_id: { type: DataTypes.INTEGER, allowNull: false, references: { model: User, key: 'id' } },
  seller_id: { type: DataTypes.INTEGER, allowNull: false, references: { model: User, key: 'id' } },
  package_id: { type: DataTypes.INTEGER, allowNull: false, references: { model: Package, key: 'id' } },
  amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  status: { type: DataTypes.ENUM('pending', 'completed', 'failed', 'cancelled'), defaultValue: 'pending', allowNull: false },
  recipient_phone: { type: DataTypes.STRING, allowNull: true },
  recipient_name: { type: DataTypes.STRING, allowNull: true },
  network: { type: DataTypes.STRING, allowNull: true }
}, { timestamps: true });

// ---------- Associations ----------
User.hasMany(Transaction, { as: 'buyerTransactions', foreignKey: 'buyer_id' });
User.hasMany(Transaction, { as: 'sellerTransactions', foreignKey: 'seller_id' });
Transaction.belongsTo(User, { as: 'buyer', foreignKey: 'buyer_id' });
Transaction.belongsTo(User, { as: 'seller', foreignKey: 'seller_id' });
Transaction.belongsTo(Package, { as: 'package', foreignKey: 'package_id' });
Package.hasMany(Transaction, { foreignKey: 'package_id' });
Package.belongsTo(User, { as: 'seller', foreignKey: 'createdBy' });

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

async function isAdmin(req, res, next) {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admins only.' });
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

// ---------- Register ----------
app.post('/api/register', async (req, res) => {
  try {
    const { username, email, phone, password, role } = req.body;
    if (!username || !email || !password) {
      return res.status(400).json({ success: false, message: 'Username, email and password are required' });
    }
    const existingUser = await User.findOne({
      where: { [Op.or]: [{ username }, { email }, { phone: phone || null }] }
    });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'User already exists with that username, email, or phone' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const userRole = (role === 'seller') ? 'seller' : 'customer';
    await User.create({ username, email, phone: phone || null, password: hashedPassword, role: userRole });
    res.json({ success: true, message: 'User registered successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ---------- Login ----------
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ success: false, message: 'Username/email/phone and password are required' });
    }
    const user = await User.findOne({
      where: { [Op.or]: [{ username }, { email: username }, { phone: username }] }
    });
    if (!user) return res.status(401).json({ success: false, message: 'Invalid credentials' });
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) return res.status(401).json({ success: false, message: 'Invalid credentials' });
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
        wallet_balance: parseFloat(user.wallet_balance)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Server error during login' });
  }
});

// ---------- Profile ----------
app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: ['id', 'username', 'email', 'phone', 'role', 'wallet_balance']
    });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    const userData = user.toJSON();
    userData.wallet_balance = parseFloat(userData.wallet_balance);
    res.json({ success: true, user: userData });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Public Packages (with seller info) ----------
app.get('/api/packages', async (req, res) => {
  try {
    const packages = await Package.findAll({
      include: [{ model: User, as: 'seller', attributes: ['username', 'phone'] }],
      order: [['createdAt', 'DESC']]
    });
    res.json(packages);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Seller Package Endpoints ----------
app.get('/api/seller/packages', authenticateToken, isSeller, async (req, res) => {
  try {
    const packages = await Package.findAll({ where: { createdBy: req.user.id }, order: [['createdAt', 'DESC']] });
    res.json(packages);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.post('/api/packages', authenticateToken, isSeller, async (req, res) => {
  try {
    const { name, price, dataSize, validity } = req.body;
    if (!name || !price || !dataSize || !validity) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }
    const newPackage = await Package.create({ name, price, dataSize, validity, createdBy: req.user.id });
    res.status(201).json({ success: true, package: newPackage });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.put('/api/seller/packages/:id', authenticateToken, isSeller, async (req, res) => {
  try {
    const pkg = await Package.findOne({ where: { id: req.params.id, createdBy: req.user.id } });
    if (!pkg) return res.status(404).json({ success: false, message: 'Package not found' });
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

app.delete('/api/seller/packages/:id', authenticateToken, isSeller, async (req, res) => {
  try {
    const deleted = await Package.destroy({ where: { id: req.params.id, createdBy: req.user.id } });
    if (deleted === 0) return res.status(404).json({ success: false, message: 'Package not found' });
    res.json({ success: true, message: 'Package deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Wallet Endpoints ----------
app.post('/api/wallet/deposit', authenticateToken, async (req, res) => {
  try {
    const { amount, method } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Invalid amount' });
    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    const newBalance = parseFloat(user.wallet_balance) + parseFloat(amount);
    user.wallet_balance = newBalance;
    await user.save();
    res.json({ success: true, message: `Deposited ${amount} via ${method}`, newBalance });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.post('/api/wallet/withdraw', authenticateToken, async (req, res) => {
  try {
    const { amount, phoneNumber, network } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ success: false, message: 'Invalid amount' });
    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    const currentBalance = parseFloat(user.wallet_balance);
    if (amount > currentBalance) return res.status(400).json({ success: false, message: 'Insufficient balance' });
    const newBalance = currentBalance - amount;
    user.wallet_balance = newBalance;
    await user.save();
    res.json({ success: true, message: `Withdrawal of ${amount} to ${network} ${phoneNumber} processed`, newBalance });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Purchase Endpoint (with recipient details) ----------
app.post('/api/purchase', authenticateToken, async (req, res) => {
  const { packageId, recipientPhone, recipientName, network } = req.body;
  if (!packageId) {
    return res.status(400).json({ success: false, message: 'Package ID required' });
  }
  const t = await sequelize.transaction();
  try {
    const pkg = await Package.findByPk(packageId, { transaction: t });
    if (!pkg) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Package not found' });
    }
    const buyer = await User.findByPk(req.user.id, { transaction: t });
    if (!buyer) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    // Extract numeric price from string like "TZS 1,000"
    const amount = parseFloat(pkg.price.replace(/[^0-9.-]/g, ''));
    const buyerBalance = parseFloat(buyer.wallet_balance);
    if (buyerBalance < amount) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Insufficient wallet balance' });
    }
    const seller = await User.findByPk(pkg.createdBy, { transaction: t });
    if (!seller) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Seller not found' });
    }
    buyer.wallet_balance = buyerBalance - amount;
    seller.wallet_balance = parseFloat(seller.wallet_balance) + amount;
    await buyer.save({ transaction: t });
    await seller.save({ transaction: t });
    await Transaction.create({
      buyer_id: buyer.id,
      seller_id: seller.id,
      package_id: pkg.id,
      amount: amount,
      status: 'completed',
      recipient_phone: recipientPhone || null,
      recipient_name: recipientName || null,
      network: network || null
    }, { transaction: t });
    await t.commit();
    res.json({
      success: true,
      message: 'Purchase successful',
      newBalance: buyer.wallet_balance
    });
  } catch (error) {
    await t.rollback();
    console.error(error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Seller Orders ----------
app.get('/api/seller/orders', authenticateToken, isSeller, async (req, res) => {
  try {
    const orders = await Transaction.findAll({
      where: { seller_id: req.user.id },
      include: [
        { model: User, as: 'buyer', attributes: ['id', 'username', 'phone'] },
        { model: Package, as: 'package', attributes: ['id', 'name', 'price'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    res.json({ success: true, orders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Buyer Orders ----------
app.get('/api/buyer/orders', authenticateToken, async (req, res) => {
  try {
    const orders = await Transaction.findAll({
      where: { buyer_id: req.user.id },
      include: [
        { model: User, as: 'seller', attributes: ['id', 'username', 'phone'] },
        { model: Package, as: 'package', attributes: ['id', 'name', 'price'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    res.json({ success: true, orders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Admin Endpoints ----------
app.get('/api/admin/users', authenticateToken, isAdmin, async (req, res) => {
  try {
    const users = await User.findAll({
      attributes: ['id', 'username', 'email', 'phone', 'role', 'wallet_balance', 'is_active', 'createdAt'],
      order: [['createdAt', 'DESC']]
    });
    const usersWithNumberBalance = users.map(u => ({
      ...u.toJSON(),
      wallet_balance: parseFloat(u.wallet_balance)
    }));
    res.json({ success: true, users: usersWithNumberBalance });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/admin/total-balance', authenticateToken, isAdmin, async (req, res) => {
  try {
    const result = await User.sum('wallet_balance');
    res.json({ success: true, totalBalance: result || 0 });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.patch('/api/admin/users/:id/toggle-active', authenticateToken, isAdmin, async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.role === 'admin') return res.status(403).json({ success: false, message: 'Cannot restrict admin' });
    user.is_active = !user.is_active;
    await user.save();
    res.json({ success: true, is_active: user.is_active });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.delete('/api/admin/users/:id', authenticateToken, isAdmin, async (req, res) => {
  const userId = req.params.id;
  const t = await sequelize.transaction();
  try {
    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.role === 'admin') return res.status(403).json({ success: false, message: 'Cannot delete admin' });
    await Package.destroy({ where: { createdBy: userId }, transaction: t });
    await Transaction.destroy({ where: { buyer_id: userId }, transaction: t });
    await Transaction.destroy({ where: { seller_id: userId }, transaction: t });
    await user.destroy({ transaction: t });
    await t.commit();
    res.json({ success: true, message: 'User deleted' });
  } catch (error) {
    await t.rollback();
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/admin/transactions', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { status } = req.query;
    const where = status ? { status } : {};
    const transactions = await Transaction.findAll({
      where,
      include: [
        { model: User, as: 'buyer', attributes: ['id', 'username'] },
        { model: User, as: 'seller', attributes: ['id', 'username'] },
        { model: Package, as: 'package', attributes: ['id', 'name'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    const transactionsWithNumberAmount = transactions.map(t => ({
      ...t.toJSON(),
      amount: parseFloat(t.amount)
    }));
    res.json({ success: true, transactions: transactionsWithNumberAmount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.delete('/api/admin/packages/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const deleted = await Package.destroy({ where: { id: req.params.id } });
    if (deleted === 0) return res.status(404).json({ success: false, message: 'Package not found' });
    res.json({ success: true, message: 'Package deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ---------- Start Server with Retry Logic ----------
const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');
    
    // 🔥 FORCE TABLE CREATION: alter: true creates missing tables and updates schema
    await sequelize.sync({ alter: true });
    console.log('📦 Database synced (tables created/updated)');
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 API available at http://0.0.0.0:${PORT}`);
    });
  } catch (error) {
    console.error('❌ Database connection error:', error.message);
    console.log('Retrying in 5 seconds...');
    setTimeout(startServer, 5000);
  }
};

startServer();