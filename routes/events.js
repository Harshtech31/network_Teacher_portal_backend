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
  body('category').notEmpty().withMessage('Category is required'),
  body('location').optional().notEmpty().withMessage('Location is required')
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
      description: req.body.description,
      eventType: req.body.category, // Map category to eventType
      startDate: req.body.eventDate, // Map eventDate to startDate
      endDate: req.body.eventDate, // Use same date for end date (can be enhanced later)
      location: req.body.location || 'BITS Pilani Dubai Campus', // Default location
      maxParticipants: req.body.maxParticipants || null,
      registrationRequired: req.body.registrationRequired !== false,
      isPublic: req.body.isPublic !== false,
      tags: req.body.tags || [],
      createdBy: 1, // Default user ID since no auth
      status: 'approved', // Auto-approve since no auth
      campus: 'dubai'
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