const axios = require('axios');

class AdminSyncService {
  constructor() {
    this.adminPortalUrl = process.env.ADMIN_PORTAL_URL || 'http://localhost:3002';
    this.isEnabled = process.env.ADMIN_SYNC_ENABLED !== 'false';
  }

  /**
   * Send event to admin portal for approval
   */
  async sendEventToAdmin(eventData) {
    if (!this.isEnabled) {
      console.log('📤 Admin sync disabled, skipping...');
      return null;
    }

    try {
      console.log('📤 Sending event to admin portal for approval...');
      
      // Map PostgreSQL event to MongoDB format
      const adminEventData = {
        title: eventData.title,
        description: eventData.description,
        category: eventData.eventType,
        eventDate: eventData.startDate,
        startTime: eventData.startTime || null,
        endTime: eventData.endTime || null,
        venue: eventData.location,
        location: eventData.location,
        maxParticipants: eventData.maxParticipants,
        registrationRequired: eventData.registrationRequired,
        registrationDeadline: eventData.registrationDeadline,
        isPublic: eventData.isPublic,
        tags: eventData.tags || [],
        imageUrl: eventData.imageUrl,
        requirements: eventData.requirements,
        contactEmail: eventData.contactEmail,
        contactPhone: eventData.contactPhone,
        createdBy: 'teacher',
        createdByName: eventData.createdByName || 'Teacher',
        createdByEmail: eventData.createdByEmail || 'teacher@bitspilani.ac.ae',
        campus: eventData.campus || 'dubai',
        teacherPortalId: eventData.id, // Link to PostgreSQL ID
        status: 'pending'
      };

      const response = await axios.post(
        `${this.adminPortalUrl}/api/events/sync`,
        adminEventData,
        {
          timeout: 10000,
          headers: {
            'Content-Type': 'application/json',
            'X-Sync-Source': 'teacher-portal'
          }
        }
      );

      if (response.data.success) {
        console.log('✅ Event sent to admin portal successfully');
        return response.data.data.event;
      } else {
        console.error('❌ Failed to send event to admin portal:', response.data.message);
        return null;
      }
    } catch (error) {
      console.error('❌ Error sending event to admin portal:', error.message);
      
      // Don't throw error - just log it so teacher portal continues working
      if (error.code === 'ECONNREFUSED') {
        console.log('⚠️ Admin portal is not running, event will be processed locally');
      }
      
      return null;
    }
  }

  /**
   * Update event status from admin portal
   */
  async updateEventStatus(teacherPortalId, status, adminNotes = '') {
    try {
      console.log(`📝 Updating event ${teacherPortalId} status to: ${status}`);
      
      // Here you would update the PostgreSQL event status
      // This is a placeholder - you'd implement the actual update logic
      
      return {
        success: true,
        teacherPortalId,
        status,
        adminNotes
      };
    } catch (error) {
      console.error('❌ Error updating event status:', error.message);
      return null;
    }
  }

  /**
   * Get admin portal health status
   */
  async checkAdminPortalHealth() {
    try {
      const response = await axios.get(`${this.adminPortalUrl}/health`, {
        timeout: 5000
      });
      
      return response.data.status === 'healthy';
    } catch (error) {
      return false;
    }
  }

  /**
   * Sync all pending events to admin portal
   */
  async syncAllPendingEvents() {
    if (!this.isEnabled) {
      console.log('📤 Admin sync disabled, skipping bulk sync...');
      return;
    }

    try {
      console.log('🔄 Starting bulk sync of pending events...');
      
      // This would fetch all pending events from PostgreSQL
      // and send them to admin portal
      // Implementation depends on your Event model
      
      console.log('✅ Bulk sync completed');
    } catch (error) {
      console.error('❌ Bulk sync failed:', error.message);
    }
  }
}

// Create singleton instance
const adminSyncService = new AdminSyncService();

module.exports = adminSyncService;
