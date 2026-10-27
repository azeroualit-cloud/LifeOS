import Foundation

// Standalone benchmark; never included in the app target.
// Compile with -O plus Models, NativeModels, NativePlatformContract and NativeCalendarWindow.
private enum LegacyCalendar {
    static func formatter(_ pattern: String, _ locale: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier:locale)
        f.timeZone = CivilDate.calendar.timeZone; f.dateFormat = pattern; return f
    }
    static func date(_ text: String) -> Date { formatter("yyyy-MM-dd","en_US_POSIX").date(from:text)! }
    static func day(_ date: Date) -> String { formatter("yyyy-MM-dd","en_US_POSIX").string(from:date) }
    static func label(_ text: String) -> String { formatter("EEE d MMM","it_IT").string(from:date(text)) }
    static func grid(_ month: String) -> [String] {
        let first=date(month+"-01"), offset=(CivilDate.calendar.component(.weekday,from:first)+5)%7
        let count=CivilDate.calendar.range(of:.day,in:.month,for:first)!.count
        return (0..<((count+offset+6)/7)*7).map {
            day(CivilDate.calendar.date(byAdding:.day,value:$0-offset,to:date(day(first)))!)
        }
    }
}
@main struct CalendarBenchmark {
    static func main() {
        print("months,cells,legacy_ms,optimized_ms,equal_output")
        for radius in [3,6,18] {
            let months=NativeCalendarWindow.months(around:"2026-10",radius:radius)
            let start=Date()
            let old=months.flatMap { month in LegacyCalendar.grid(month).map { day in
                day+"|"+LegacyCalendar.label(day)+"|"+String(CivilDate.calendar.component(.weekday,from:LegacyCalendar.date(day)))
            } }
            let oldMS=Date().timeIntervalSince(start)*1000, next=Date()
            let new=months.flatMap { month in CivilDate.gridDates(month).map { date in
                CivilDate.day(date)+"|"+CivilDate.label(date)+"|"+String(CivilDate.calendar.component(.weekday,from:date))
            } }
            let newMS=Date().timeIntervalSince(next)*1000
            precondition(old==new,"Civil dates and labels must remain identical")
            print("\(months.count),\(new.count),\(oldMS),\(newMS),true")
        }
    }
}
