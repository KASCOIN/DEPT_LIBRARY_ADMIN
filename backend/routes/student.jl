using Genie.Router
using Genie.Requests
using ..StudentController

# Serve student.html at /student route
route("/student", method=GET) do
  student_file = joinpath(@__DIR__, "..", "..", "frontend", "student.html")
  if isfile(student_file)
    return read(student_file, String)
  else
    return "Student page not found"
  end
end

# Serve index.html at / route
route("/", method=GET) do
  index_file = joinpath(@__DIR__, "..", "..", "frontend", "admin.html")
  if isfile(index_file)
    return read(index_file, String)
  else
    return "Home page not found"
  end
end

# Student API Routes

# Login - POST with email and password
route("/api/student/login", StudentController.login_student, method=POST)

# Get student profile by ID (for dashboard)
route("/api/student/profile/:user_id", StudentController.get_student_profile, method=GET)

# Get signed URL for viewing materials
route("/api/student/materials/view", StudentController.get_material_view_url, method=POST)

println("[✓] Student routes loaded")
