const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Event = sequelize.define('Event', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  title: {
    type: DataTypes.STRING(200),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Event title is required' },
      len: { args: [1, 200], msg: 'Title cannot exceed 200 characters' }
    }
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Event description is required' },
      len: { args: [1, 2000], msg: 'Description cannot exceed 2000 characters' }
    }
  },
  eventType: {
    type: DataTypes.ENUM('academic', 'cultural', 'sports', 'workshop', 'seminar', 'competition', 'social'),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Event category is required' }
    }
  },
  startDate: {
    type: DataTypes.DATE,
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Start date is required' },
      isDate: { msg: 'Invalid date format' }
    }
  },
  endDate: {
    type: DataTypes.DATE,
    allowNull: false,
    validate: {
      notEmpty: { msg: 'End date is required' },
      isDate: { msg: 'Invalid date format' }
    }
  },
  location: {
    type: DataTypes.STRING(200),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Location is required' },
      len: { args: [1, 200], msg: 'Location cannot exceed 200 characters' }
    }
  },
  maxParticipants: {
    type: DataTypes.INTEGER,
    allowNull: true,
    validate: {
      min: { args: [1], msg: 'Max participants must be at least 1' },
      max: { args: [10000], msg: 'Max participants cannot exceed 10000' }
    }
  },
  registrationDeadline: {
    type: DataTypes.DATE,
    allowNull: true
  },
  registrationRequired: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  isPublic: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  tags: {
    type: DataTypes.JSON,
    defaultValue: []
  },
  imageUrl: {
    type: DataTypes.STRING(500),
    allowNull: true,
    validate: {
      isUrl: { msg: 'Invalid image URL' }
    }
  },
  requirements: {
    type: DataTypes.TEXT,
    allowNull: true,
    validate: {
      len: { args: [0, 1000], msg: 'Requirements cannot exceed 1000 characters' }
    }
  },
  contactEmail: {
    type: DataTypes.STRING(255),
    allowNull: true,
    validate: {
      isEmail: { msg: 'Invalid email format' }
    }
  },
  contactPhone: {
    type: DataTypes.STRING(20),
    allowNull: true
  },
  createdBy: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  status: {
    type: DataTypes.ENUM('draft', 'pending', 'approved', 'rejected', 'cancelled'),
    defaultValue: 'draft'
  },
  participantCount: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  campus: {
    type: DataTypes.ENUM('dubai', 'pilani', 'goa', 'hyderabad'),
    defaultValue: 'dubai'
  },
  rejectionReason: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  approvedBy: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  approvedAt: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  tableName: 'events',
  timestamps: true,
  underscored: true
});

// Instance methods
Event.prototype.isRegistrationOpen = function() {
  if (!this.registrationRequired) return false;
  if (this.registrationDeadline && new Date() > this.registrationDeadline) return false;
  if (this.maxParticipants && this.participantCount >= this.maxParticipants) return false;
  return this.status === 'approved' && this.isActive;
};

Event.prototype.canUserRegister = function(userId) {
  return this.isRegistrationOpen();
};

Event.prototype.getFormattedDate = function() {
  return this.startDate.toLocaleDateString('en-AE', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'Asia/Dubai'
  });
};

// Class methods
Event.findUpcoming = function(limit = 10) {
  return this.findAll({
    where: {
      startDate: {
        [sequelize.Sequelize.Op.gte]: new Date()
      },
      status: 'approved',
      isActive: true
    },
    order: [['startDate', 'ASC']],
    limit
  });
};

Event.findByCategory = function(category) {
  return this.findAll({
    where: {
      eventType: category,
      status: 'approved',
      isActive: true
    },
    order: [['startDate', 'ASC']]
  });
};

Event.findByCampus = function(campus) {
  return this.findAll({
    where: {
      campus,
      status: 'approved',
      isActive: true
    },
    order: [['startDate', 'ASC']]
  });
};

module.exports = Event;
