const express = require('express');
const { body, validationResult } = require('express-validator');
const { Event } = require('../models');
const adminSyncService = require('../services/adminSync');

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
  body('eventLink').isURL().withMessage('Valid event link is required'),
  body('description').optional().notEmpty().withMessage('Description cannot be empty if provided'),
  body('eventDate').optional().isISO8601().withMessage('Valid event date is required'),
  body('category').optional().notEmpty().withMessage('Category cannot be empty if provided'),
  body('venue').optional().notEmpty().withMessage('Venue cannot be empty if provided')
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

    // Map frontend fields to database fields
    const eventData = {
      title: req.body.title,
      description: req.body.description || 'No description provided',
      eventType: req.body.category || 'general', // Map category to eventType
      startDate: req.body.eventDate || new Date().toISOString().split('T')[0], // Default to today if not provided
      endDate: req.body.eventDate || new Date().toISOString().split('T')[0], // Use same date for end date
      location: req.body.venue || 'Online/TBD', // Map venue to location
      eventLink: req.body.eventLink, // Store the event link
      maxParticipants: req.body.maxParticipants || null,
      registrationRequired: req.body.registrationRequired !== false,
      isPublic: req.body.isPublic !== false,
      tags: req.body.tags || [],
      createdBy: 1, // Default user ID since no auth
      status: 'approved', // Auto-approve since no auth
      campus: 'dubai'
    };

    const event = await Event.create(eventData);

    // Send event to admin portal for approval
    try {
      await adminSyncService.sendEventToAdmin(event);
      console.log('✅ Event sent to admin portal for approval');
    } catch (syncError) {
      console.error('⚠️ Failed to sync with admin portal:', syncError.message);
      // Continue anyway - event is still created locally
    }

    res.status(201).json({
      success: true,
      message: 'Event created successfully and sent for admin approval',
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

/**
 * @route   GET /api/events/:id
 * @desc    Get single event by ID
 * @access  Public
 */
router.get('/:id', async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.id);
    
    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }

    res.json({
      success: true,
      data: { event }
    });
  } catch (error) {
    console.error('Get event error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch event',
      error: error.message
    });
  }
});

/**
 * @route   PUT /api/events/:id
 * @desc    Update event by ID
 * @access  Public
 */
router.put('/:id', [
  body('title').optional().notEmpty().withMessage('Title cannot be empty'),
  body('description').optional().notEmpty().withMessage('Description cannot be empty'),
  body('eventDate').optional().isISO8601().withMessage('Valid event date is required'),
  body('category').optional().notEmpty().withMessage('Category cannot be empty')
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

    const event = await Event.findByPk(req.params.id);
    
    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }

    // Map frontend fields to database fields
    const updateData = {};
    if (req.body.title) updateData.title = req.body.title;
    if (req.body.description) updateData.description = req.body.description;
    if (req.body.category) updateData.eventType = req.body.category;
    if (req.body.eventDate) updateData.startDate = req.body.eventDate;
    if (req.body.eventDate) updateData.endDate = req.body.eventDate;
    if (req.body.location) updateData.location = req.body.location;
    if (req.body.maxParticipants !== undefined) updateData.maxParticipants = req.body.maxParticipants;
    if (req.body.registrationRequired !== undefined) updateData.registrationRequired = req.body.registrationRequired;
    if (req.body.isPublic !== undefined) updateData.isPublic = req.body.isPublic;
    if (req.body.tags) updateData.tags = req.body.tags;

    await event.update(updateData);

    res.json({
      success: true,
      message: 'Event updated successfully',
      data: { event }
    });
  } catch (error) {
    console.error('Update event error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update event',
      error: error.message
    });
  }
});

/**
 * @route   DELETE /api/events/:id
 * @desc    Delete event by ID
 * @access  Public
 */
router.delete('/:id', async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.id);
    
    if (!event) {
      return res.status(404).json({
        success: false,
        message: 'Event not found'
      });
    }

    await event.destroy();

    res.json({
      success: true,
      message: 'Event deleted successfully'
    });
  } catch (error) {
    console.error('Delete event error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete event',
      error: error.message
    });
  }
});

module.exports = router;