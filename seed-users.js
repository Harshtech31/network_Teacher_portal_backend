const bcrypt = require('bcrypt');
const { User } = require('./models');
require('dotenv').config();

const seedUsers = async () => {
  try {
    console.log('🌱 Seeding test users...');

    // Hash passwords
    const adminPassword = await bcrypt.hash('admin123', 10);
    const teacherPassword = await bcrypt.hash('teacher123', 10);

    // Create admin user
    const admin = await User.findOrCreate({
      where: { email: 'admin@bitspilani.ae' },
      defaults: {
        email: 'admin@bitspilani.ae',
        password: adminPassword,
        firstName: 'Test',
        lastName: 'Admin',
        role: 'admin',
        department: 'Administration',
        isActive: true
      }
    });

    // Create teacher user
    const teacher = await User.findOrCreate({
      where: { email: 'teacher@bitspilani.ae' },
      defaults: {
        email: 'teacher@bitspilani.ae',
        password: teacherPassword,
        firstName: 'Test',
        lastName: 'Teacher',
        role: 'teacher',
        department: 'Computer Science',
        isActive: true
      }
    });

    console.log('✅ Test users created successfully!');
    console.log('📋 Test Credentials:');
    console.log('   Admin: admin@bitspilani.ae / admin123');
    console.log('   Teacher: teacher@bitspilani.ae / teacher123');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding users:', error);
    process.exit(1);
  }
};

seedUsers();
