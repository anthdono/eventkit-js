
notes:
- _cdecl_ refers to [this](https://forums.swift.org/t/formalizing-cdecl/40677/11) undocumented swift attribute

---

- _native_ package (contains swift files that compile to dynamic libraries. these dynamic libraries contain exported symbols which are used for interfacing)
	-  EventStore.swift
		- [x] implement init()
			- https://developer.apple.com/documentation/eventkit/ekeventstore/1507252-init
		- [x] implement cdecl init(sources: [EKSources]) 
			-  https://developer.apple.com/documentation/eventkit/ekeventstore/1507179-init
		- [x] implement cdecl freePointer 
		- [x] implement cdecl sources() 
			-  https://developer.apple.com/documentation/eventkit/ekeventstore/1507315-sources
		- [x] implement cdecl calendars(for: EKEntityType)
			- https://developer.apple.com/documentation/eventkit/ekeventstore/1507128-calendars
		- [ ] ~~implement predicateForEvents(startDate: Date, endDate: Date, calendars: [EKCalendars])~~
			-  https://developer.apple.com/documentation/eventkit/ekeventstore/1507479-predicateforevents
		- [ ] ~~implement cdecl requestAccess function~~
		- [x] implement cdecl events(matching: predicate) 
			-  https://developer.apple.com/documentation/eventkit/ekeventstore/1507183-events
		- [ ]  implement cdecl event(withIdentifier: String)
	- models
		- [x] use codable protocol on models to enable serialisation
		- [x] define EKCalendarModel 
			- [x] implement toBuiltin method
			- [x] implement init from builtin type
		- [x] define EKSourceModel
			- [x] implement init from builtin type
			- [x] implement toBuiltin method
		- [x] define EKEventModel
		- [x] define NSPredicateModel
		- [x] define CGColorModel
			- [x] implement init from builtin
			- [x] ~~implement conversion of CGColor components property to rgb~~
		      
- _EventKitJS_ wrapper
	- [x] implement darwin os check
	- [x] implement static getter exposing EventStore
	- [x] implement static method to check calendar/reminder permissions
	- EventStore class
		- [x] implement constructor for both default EKEventStore() instantiation and EKEventStore(sources: [EKSources]) instantiation with sources argument
		- [x] implement sources() method
		- [x] implement calendars(for: EKEntityType) method
		- [x] implement predicateForEvents(startDate: Date, endDate: Date, calendars: [EKCalendars])
		- [x] implement events(matching: NSPredicate) method
	 - models
		 - [x] define a model that represents calendar/reminder permission status
		 - [x] define EKCalendar
		 - [x] define CGColor
		 - [x] define EKSource
		 - [ ] define EKEvent
		 - [ ] define EKCalendarItem
		 - [x] define NSPredicate
		 - [x] define EKEntityType
	 - models-adapter
		 - 







