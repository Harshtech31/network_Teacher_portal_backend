const express = require('express');
const Event = require('../models/Event');
const auth = require('../middleware/auth');
const requireTeacher = require('../middleware/requireTeacher');

const router = express.Router();

// Apply authentication and teacher role check to all routes
router.use(auth);
router.use(requireTeacher);

/**
 * @route   GET /api/teachers/dashboard
 * @desc    Get dashboard statistics for teacher
 * @access  Private (Teachers only)
 */
router.get('/dashboard', async (req, res) => {
  try {
    const teacherId = req.user.id;

    // Get event statistics
    const totalEvents = await Event.countDocuments({ createdBy: teacherId });
    const pendingEvents = await Event.countDocuments({ createdBy: teacherId, status: 'pending' });
    const approvedEvents = await Event.countDocuments({ createdBy: teacherId, status: 'approved' });
    const rejectedEvents = await Event.countDocuments({ createdBy: teacherId, status: 'rejected' });
    const cancelledEvents = await Event.countDocuments({ createdBy: teacherId, status: 'cancelled' });

    // Get upcoming events (approved events in the future)
    const upcomingEvents = await Event.countDocuments({
      createdBy: teacherId,
      status: 'approved',
      eventDate: { $gte: new Date() }
    });

    // Get total participants across all events
    const participantStats = await Event.aggregate([
      { $match: { createdBy: teacherId } },
      { $group: { _id: null, totalParticipants: { $sum: '$participantCount' } } }
    ]);
    const totalParticipants = participantStats.length > 0 ? participantStats[0].totalParticipants : 0;

    // Get events by category
    const eventsByCategory = await Event.aggregate([
      { $match: { createdBy: teacherId } },
      { $group: { _id: '$category', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    // Get recent events (last 5)
    const recentEvents = await Event.find({ createdBy: teacherId })
      .sort({ createdAt: -1 })
      .limit(5)
      .select('title status eventDate participantCount category');

    // Get monthly event creation stats (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const monthlyStats = await Event.aggregate([
      {
        $match: {
          createdBy: teacherId,
          createdAt: { $gte: sixMonthsAgo }
        }
      },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' }
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } }
    ]);

    res.json({
      success: true,
      data: {
        overview: {
          totalEvents,
          pendingEvents,
          approvedEvents,
          rejectedEvents,
          cancelledEvents,
          upcomingEvents,
          totalParticipants
        },
        eventsByCategory,
        recentEvents,
        monthlyStats
      }
    });

  } catch (error) {
    console.error('Error fetching dashboard data:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch dashboard data'
    });
  }
});

/**
 * @route   GET /api/teachers/stats
 * @desc    Get detailed statistics for teacher
 * @access  Private (Teachers only)
 */
router.get('/stats', async (req, res) => {
  try {
    const teacherId = req.user.id;
    const { period = '30' } = req.query; // days

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(period));

    // Events created in period
    const eventsInPeriod = await Event.countDocuments({
      createdBy: teacherId,
      createdAt: { $gte: startDate }
    });

    // Approval rate
    const totalSubmitted = await Event.countDocuments({ createdBy: teacherId });
    const totalApproved = await Event.countDocuments({ createdBy: teacherId, status: 'approved' });
    const approvalRate = totalSubmitted > 0 ? ((totalApproved / totalSubmitted) * 100).toFixed(1) : 0;

    // Average participants per event
    const avgParticipants = await Event.aggregate([
      { $match: { createdBy: teacherId, status: 'approved' } },
      { $group: { _id: null, avgParticipants: { $avg: '$participantCount' } } }
    ]);
    const averageParticipants = avgParticipants.length > 0 ? Math.round(avgParticipants[0].avgParticipants) : 0;

    // Most popular event category
    const popularCategory = await Event.aggregate([
      { $match: { createdBy: teacherId } },
      { $group: { _id: '$category', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 1 }
    ]);
    const mostPopularCategory = popularCategory.length > 0 ? popularCategory[0]._id : 'N/A';

    res.json({
      success: true,
      data: {
        period: parseInt(period),
        eventsInPeriod,
        approvalRate: parseFloat(approvalRate),
        averageParticipants,
        mostPopularCategory,
        totalSubmitted,
        totalApproved
      }
    });

  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch statistics'
    });
  }
});

module.exports = router;
