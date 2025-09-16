const express = require('express');
const { body, validationResult, query } = require('express-validator');
const Event = require('../models/Event');
const auth = require('../middleware/auth');
const requireTeacher = require('../middleware/requireTeacher');

const router = express.Router();

// Apply authentication and teacher role check to all routes
router.use(auth);
router.use(requireTeacher);

/**
 * @route   GET /api/events
 * @desc    Get all events created by the teacher
 * @access  Private (Teachers only)
 */
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 10, status, category, search } = req.query;
    const teacherId = req.user.id;

    // Build query
    const query = { createdBy: teacherId };
    
    if (status) query.status = status;
    if (category) query.category = category;
    if (search) {
      query.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    // Execute query with pagination
    const events = await Event.find(query)
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const totalEvents = await Event.countDocuments(query);
    const totalPages = Math.ceil(totalEvents / limit);

    res.json({
      success: true,
      data: {
        events,
        pagination: {
          currentPage: parseInt(page),
          totalPages,
          totalEvents,
          hasNext: page < totalPages,
          hasPrev: page > 1
        }
      }
    });

  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch events'
    });
  }
});

/**
 * @route   POST /api/events
 * @desc    Create a new event
 * @access  Private (Teachers only)
 */
router.post('/', [
  body('title').trim().isLength({ min: 3, max: 200 }).withMessage('Title must be between 3-200 characters'),
  body('description').trim().isLength({ min: 10, max: 2000 }).withMessage('Description must be between 10-2000 characters'),
  body('category').isIn(['academic', 'cultural', 'sports', 'workshop', 'seminar', 'competition', 'social']).withMessage('Invalid category'),
  body('eventDate').isISO8601().withMessage('Valid event date is required'),
  body('startTime').matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Valid start time is required (HH:MM)'),
  body('endTime').matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Valid end time is required (HH:MM)'),
  body('venue').trim().isLength({ min: 3, max: 200 }).withMessage('Venue must be between 3-200 characters'),
  body('maxParticipants').optional().isInt({ min: 1, max: 10000 }).withMessage('Max participants must be between 1-10000'),
  body('registrationRequired').isBoolean().withMessage('Registration required must be true or false'),
  body('tags').optional().isArray().withMessage('Tags must be an array'),
  body('isPublic').isBoolean().withMessage('Is public must be true or false')
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const {
      title,
      description,
      category,
      eventDate,
      startTime,
      endTime,
      venue,
      maxParticipants,
      registrationRequired,
      tags,
      isPublic,
      imageUrl,
      requirements,
      contactEmail,
      contactPhone
    } = req.body;

    // Validate event date is in the future
    const eventDateTime = new Date(`${eventDate}T${startTime}`);
    if (eventDateTime <= new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Event date and time must be in the future'
      });
    }

    // Validate end time is after start time
    const startDateTime = new Date(`${eventDate}T${startTime}`);
    const endDateTime = new Date(`${eventDate}T${endTime}`);
    if (endDateTime <= startDateTime) {
      return res.status(400).json({
        success: false,
        message: 'End time must be after start time'
      });
    }

    const event = new Event({
      title,
      description,
      category,
      eventDate,
      startTime,
      endTime,
      venue,
      maxParticipants,
      registrationRequired,
      tags: tags || [],
      isPublic,
      imageUrl,
      requirements,
      contactEmail: contactEmail || req.user.email,
      contactPhone,
      createdBy: req.user.id,
      createdByName: req.user.name,
      createdByEmail: req.user.email,
      campus: req.user.campus || 'dubai'
    });

    await event.save();

    res.status(201).json({
      success: true,
      message: 'Event created successfully and submitted for approval',
      data: { event }
    });

  } catch (error) {
    console.error('Error creating event:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create event'
    });
  }
});

/**
 * @route   GET /api/events/:id
 * @desc    Get a specific event by ID
 * @access  Private (Teachers only - own events)
 */
router.get('/:id', async (req, res) => {
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
        message: 'Access denied. You can only view your own events.'
      });
    }

    res.json({
      success: true,
      data: { event }
    });

  } catch (error) {
    console.error('Error fetching event:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch event'
    });
  }
});

/**
 * @route   PUT /api/events/:id
 * @desc    Update an event
 * @access  Private (Teachers only - own events)
 */
router.put('/:id', [
  body('title').optional().trim().isLength({ min: 3, max: 200 }).withMessage('Title must be between 3-200 characters'),
  body('description').optional().trim().isLength({ min: 10, max: 2000 }).withMessage('Description must be between 10-2000 characters'),
  body('category').optional().isIn(['academic', 'cultural', 'sports', 'workshop', 'seminar', 'competition', 'social']).withMessage('Invalid category'),
  body('eventDate').optional().isISO8601().withMessage('Valid event date is required'),
  body('startTime').optional().matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Valid start time is required (HH:MM)'),
  body('endTime').optional().matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/).withMessage('Valid end time is required (HH:MM)'),
  body('venue').optional().trim().isLength({ min: 3, max: 200 }).withMessage('Venue must be between 3-200 characters'),
  body('maxParticipants').optional().isInt({ min: 1, max: 10000 }).withMessage('Max participants must be between 1-10000'),
  body('registrationRequired').optional().isBoolean().withMessage('Registration required must be true or false'),
  body('tags').optional().isArray().withMessage('Tags must be an array'),
  body('isPublic').optional().isBoolean().withMessage('Is public must be true or false')
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

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
