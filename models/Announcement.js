const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Announcement = sequelize.define('Announcement', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  title: {
    type: DataTypes.STRING(255),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Announcement title is required' },
      len: { args: [1, 255], msg: 'Title cannot exceed 255 characters' }
    }
  },
  content: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Announcement content is required' }
    }
  },
  priority: {
    type: DataTypes.ENUM('low', 'normal', 'high', 'urgent'),
    defaultValue: 'normal'
  },
  targetAudience: {
    type: DataTypes.ENUM('all', 'teachers', 'admins', 'department'),
    defaultValue: 'all'
  },
  department: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  isPublished: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  publishedAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  expiresAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  createdBy: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  }
}, {
  tableName: 'announcements',
  timestamps: true,
  underscored: true
});

// Instance methods
Announcement.prototype.isActive = function() {
  if (!this.isPublished) return false;
  if (this.expiresAt && new Date() > this.expiresAt) return false;
  return true;
};

// Class methods
Announcement.findActive = function() {
  return this.findAll({
    where: {
      isPublished: true,
      [sequelize.Sequelize.Op.or]: [
        { expiresAt: null },
        { expiresAt: { [sequelize.Sequelize.Op.gt]: new Date() } }
      ]
    },
    order: [['priority', 'DESC'], ['publishedAt', 'DESC']]
  });
};

module.exports = Announcement;
