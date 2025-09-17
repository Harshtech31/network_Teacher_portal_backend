const bcrypt = require('bcryptjs');
const { User } = require('./models');
require('dotenv').config();

const debugLogin = async () => {
  try {
    console.log('🔍 Debug Login Process...');
    
    const email = 'admin@bitspilani.ae';
    const password = 'admin123';
    
    // Find user
    console.log('1. Looking for user with email:', email);
    const user = await User.findOne({ where: { email } });
    
    if (!user) {
      console.log('❌ User not found!');
      return;
    }
    
    console.log('✅ User found:');
    console.log('   ID:', user.id);
    console.log('   Email:', user.email);
    console.log('   Name:', user.firstName, user.lastName);
    console.log('   Role:', user.role);
    console.log('   Active:', user.isActive);
    console.log('   Password hash length:', user.password ? user.password.length : 'No password');
    console.log('   Password starts with:', user.password ? user.password.substring(0, 10) : 'N/A');
    
    // Test password comparison
    console.log('\n2. Testing password comparison...');
    console.log('   Input password:', password);
    
    if (!user.password) {
      console.log('❌ No password hash stored for user!');
      return;
    }
    
    const isValid = await bcrypt.compare(password, user.password);
    console.log('   Password valid:', isValid);
    
    if (!isValid) {
      console.log('❌ Password comparison failed!');
      
      // Test with manual hash
      console.log('\n3. Testing manual hash...');
      const testHash = await bcrypt.hash(password, 10);
      console.log('   New hash:', testHash);
      const testCompare = await bcrypt.compare(password, testHash);
      console.log('   New hash comparison:', testCompare);
    } else {
      console.log('✅ Password comparison successful!');
    }
    
  } catch (error) {
    console.error('❌ Debug error:', error);
  }
  
  process.exit(0);
};

debugLogin();
