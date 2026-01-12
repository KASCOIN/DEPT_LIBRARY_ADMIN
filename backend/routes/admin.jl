# Admin routes
using Genie.Router
using ..AdminController: delete_course, delete_news, post_news, download_material, post_materials, post_timetable, post_courses, update_courses, delete_materials, get_news, get_materials, get_timetable, admin_get_courses, delete_timetable_slot, delete_timetable_day, get_active_students, admin_login, admin_logout, admin_verify_session, admin_verify_role
using HTTP

# CORS preflight handler: return required headers for browser OPTIONS requests
route("/*", method=OPTIONS) do
  return HTTP.Response(200, [
    "Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS, PUT, DELETE",
    "Access-Control-Allow-Headers" => "Content-Type, Authorization"
  ], "")
end

# ==================== AUTHENTICATION ENDPOINTS ====================
# New Supabase-based admin role verification (public)
route("/api/admin/verify-role", AdminController.admin_verify_role, method=POST)

# Legacy authentication endpoints (for backward compatibility)
route("/api/admin/auth/login", AdminController.admin_login, method=POST)
route("/api/admin/auth/logout", AdminController.admin_logout, method=POST)
route("/api/admin/auth/verify", AdminController.admin_verify_session, method=GET)

# Serve admin login page at /admin-login route
route("/admin-login", method=GET) do
  admin_login_file = joinpath(@__DIR__, "..", "..", "frontend", "admin-login.html")
  if isfile(admin_login_file)
    return read(admin_login_file, String)
  else
    return "Admin login page not found"
  end
end

# Serve admin.html at /admin route
route("/admin", method=GET) do
  admin_file = joinpath(@__DIR__, "..", "..", "frontend", "admin.html")
  if isfile(admin_file)
    return read(admin_file, String)
  else
    return "Admin page not found"
  end
end

# Serve login.html at /login route
route("/login", method=GET) do
  login_file = joinpath(@__DIR__, "..", "..", "frontend", "login.html")
  if isfile(login_file)
    return read(login_file, String)
  else
    return "Login page not found"
  end
end

# POST endpoints for uploading
route("/api/admin/news", AdminController.post_news, method=POST)
route("/api/admin/materials/download", AdminController.download_material, method=POST)
route("/api/admin/materials", AdminController.post_materials, method=POST)
route("/api/admin/timetable", AdminController.post_timetable, method=POST)
route("/api/admin/courses", AdminController.post_courses, method=POST)
route("/api/admin/courses/update", AdminController.update_courses, method=POST)

# DELETE endpoints
route("/api/admin/materials", AdminController.delete_materials, method=DELETE)
route("/api/admin/courses", AdminController.delete_course, method=DELETE)
route("/api/admin/timetable/day", AdminController.delete_timetable_day, method=DELETE)
route("/api/admin/timetable/slot", AdminController.delete_timetable_slot, method=DELETE)
route("/api/news", AdminController.delete_news, method=DELETE)

# GET endpoints for retrieving JSON
route("/api/news", AdminController.admin_get_news, method=GET)
route("/api/materials", AdminController.admin_get_materials, method=GET)
route("/api/timetable", AdminController.admin_get_timetable, method=GET)
route("/api/admin/timetable", AdminController.admin_get_timetable, method=GET)
route("/api/courses", AdminController.admin_get_courses, method=GET)
route("/api/admin/courses", AdminController.admin_get_courses, method=GET)
route("/api/admin/active-students", AdminController.get_active_students, method=GET)

route("/ping") do
  json(Dict("status" => "admin alive"))
end

println("[✓] Admin routes loaded")
