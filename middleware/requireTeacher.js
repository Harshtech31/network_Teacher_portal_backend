const requireTeacher = (req, res, next) => {
  // Check if user is authenticated (should be done by auth middleware first)
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }

  // Check if user has teacher role
  if (req.user.role !== 'teacher' && req.user.role !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Teacher role required.'
    });
  }

  next();
};

module.exports = requireTeacher;
