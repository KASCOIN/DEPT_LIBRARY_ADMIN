module Models

export News, Material, Timetable, Course

struct News
    programme::String
    level::String
    title::String
    body::String
    timestamp::String
end

struct Material
    programme::String
    level::String
    title::String
    filename::String
    timestamp::String
end

struct Timetable
    programme::String
    level::String
    title::String
    description::String
    timestamp::String
end

struct Course
    programme::String
    level::String
    code::String
    title::String
    description::String
    timestamp::String
end

end
