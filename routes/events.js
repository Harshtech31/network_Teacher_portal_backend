const express = require('express');
const { body, validationResult } = require('express-validator');
const { Event } = require('../models');

const router = express.Router();

// Simplified events API - no authentication required

/**
 * @route   GET /api/events
 * @desc    Get all events
 * @access  Public
 */
router.get('/', async (req, res) => {
  try {
    // Get all events - simplified
    const events = await Event.findAll({
      order: [['createdAt', 'DESC']],
      limit: 50 // Limit to 50 events
    });

    res.json({
      success: true,
      data: {
        events,
        total: events.length
      }
    });
  } catch (error) {
    console.error('Get events error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch events',
      error: error.message
    });
  }
});

/**
 * @route   POST /api/events
 * @desc    Create a new event
 * @access  Public
 */
router.post('/', [
  body('title').notEmpty().withMessage('Title is required'),
  body('description').notEmpty().withMessage('Description is required'),
  body('eventDate').isISO8601().withMessage('Valid event date is required'),
  body('category').notEmpty().withMessage('Category is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const eventData = {
      ...req.body,
      status: 'active' // Default status
    };

    const event = await Event.create(eventData);

    res.status(201).json({
      success: true,
      message: 'Event created successfully',
      data: { event }
    });
  } catch (error) {
    console.error('Create event error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create event',
      error: error.message
    });
  }
});

module.exports = router;
    }

    // Check if teacher owns this event
    if (event.createdBy.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only update your own events.'
      });
    }

    // Check if event can be updated (not if it's already started)
    const eventDateTime = new Date(`${event.eventDate}T${event.startTime}`);
    if (eventDateTime <= new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Cannot update event that has already started or passed'
      });
    }

    // Update event fields
    Object.keys(req.body).forEach(key => {
      if (req.body[key] !== undefined && key !== 'createdBy' && key !== 'createdAt') {
        event[key] = req.body[key];
      }
    });

    // If event was rejected and now being updated, set status back to pending
    if (event.status === 'rejected') {
      event.status = 'pending';
    }

    await event.save();

    res.json({
      success: true,
      message: 'Event updated successfully',
      data: { event }
    });

  } catch (error) {
    console.error('Error updating event:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update event'
    });
  }
});

/**
 * @route   DELETE /api/events/:id
 * @desc    Delete/Cancel an event
 * @access  Private (Teachers only - own events)
 */
router.delete('/:id', async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);

    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }

    // Check if teacher owns this event
    if (event.createdBy.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only delete your own events.'
      });
    }

    // Mark as cancelled instead of deleting
    event.status = 'cancelled';
    event.isActive = false;
    await event.save();

    res.json({
      success: true,
      message: 'Event cancelled successfully',
      data: { event }
    });

  } catch (error) {
    console.error('Error cancelling event:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to cancel event'
    });
  }
});

/**
 * @route   GET /api/events/:id/participants
 * @desc    Get participants for an event
 * @access  Private (Teachers only - own events)
 */
router.get('/:id/participants', async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);

    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }

    if (event.createdBy.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only view participants of your own events.'
      });
    }

    res.json({
      success: true,
      data: {
        participants: event.participants || [],
        participantCount: event.participantCount || 0,
        maxParticipants: event.maxParticipants
      }
    });

  } catch (error) {
    console.error('Error fetching event participants:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch participants'
    });
  }
});

module.exports = router;
