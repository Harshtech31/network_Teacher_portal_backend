const express = require('express');
const bcrypt = require('bcryptjs');
const { User } = require('./models');
require('dotenv').config();

const app = express();
app.use(express.json());

// Simple test endpoint
app.post('/test-login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    console.log('Test login attempt:', { email, password });
    
    // Find user
    const user = await User.findOne({ where: { email } });
    console.log('User found:', user ? 'YES' : 'NO');
    
    if (!user) {
      return res.json({ error: 'User not found' });
    }
    
    console.log('User details:', {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      isActive: user.isActive,
      passwordLength: user.password ? user.password.length : 0
    });
    
    // Test password
    const isValid = await bcrypt.compare(password, user.password);
    console.log('Password comparison result:', isValid);
    
    // Also test with manual hash
    const testHash = await bcrypt.hash(password, 10);
    const testCompare = await bcrypt.compare(password, testHash);
    console.log('Manual hash test:', testCompare);
    
    res.json({
      userFound: !!user,
      passwordValid: isValid,
      manualHashTest: testCompare,
      userDetails: user ? {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        isActive: user.isActive
      } : null
    });
    
  } catch (error) {
    console.error('Test login error:', error);
    res.json({ error: error.message });
  }
});

// Create a fresh user endpoint
app.post('/create-test-user', async (req, res) => {
  try {
    // Delete existing user
    await User.destroy({ where: { email: 'admin@bitspilani.ae' } });
    
    // Create new user
    const hashedPassword = await bcrypt.hash('admin123', 10);
    
    const user = await User.create({
      email: 'admin@bitspilani.ae',
      password: hashedPassword,
      firstName: 'Test',
      lastName: 'Admin',
      role: 'admin',
      department: 'Administration',
      isActive: true
    });
    
    res.json({
      success: true,
      message: 'Test user created',
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role
      }
    });
    
  } catch (error) {
    console.error('Create user error:', error);
    res.json({ error: error.message });
  }
});

const PORT = 3002;
app.listen(PORT, () => {
  console.log(`Test server running on port ${PORT}`);
  console.log(`Test endpoints:`);
  console.log(`  POST http://localhost:${PORT}/test-login`);
  console.log(`  POST http://localhost:${PORT}/create-test-user`);
});
