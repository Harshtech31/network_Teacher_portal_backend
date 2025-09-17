const { sequelize } = require('../config/database');
const User = require('./User');
const Event = require('./Event');
const EventRegistration = require('./EventRegistration');
const Announcement = require('./Announcement');

// Define associations
User.hasMany(Event, { foreignKey: 'createdBy', as: 'createdEvents' });
Event.belongsTo(User, { foreignKey: 'createdBy', as: 'creator' });

User.hasMany(Event, { foreignKey: 'approvedBy', as: 'approvedEvents' });
Event.belongsTo(User, { foreignKey: 'approvedBy', as: 'approver' });

User.hasMany(EventRegistration, { foreignKey: 'userId', as: 'registrations' });
EventRegistration.belongsTo(User, { foreignKey: 'userId', as: 'user' });

Event.hasMany(EventRegistration, { foreignKey: 'eventId', as: 'registrations' });
EventRegistration.belongsTo(Event, { foreignKey: 'eventId', as: 'event' });

User.hasMany(Announcement, { foreignKey: 'createdBy', as: 'announcements' });
Announcement.belongsTo(User, { foreignKey: 'createdBy', as: 'creator' });

// Export models and sequelize instance
module.exports = {
  sequelize,
  User,
  Event,
  EventRegistration,
  Announcement
};
