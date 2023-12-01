-- chunkname: @scripts/menu/menu_callbacks/splash_screen_callbacks.lua

SplashScreenCallbacks = class(SplashScreenCallbacks)

SplashScreenCallbacks.init = function (self, state)
	self._state = state
end

SplashScreenCallbacks.cb_error_popup_enter = function (self, args)
	self._state:cb_error_popup_enter(args)
end

SplashScreenCallbacks.cb_error_popup_item_selected = function (self, args)
	self._state:cb_error_popup_item_selected(args)
end

SplashScreenCallbacks.cb_changelog_popup_enter = function (self, args)
	self._state:cb_changelog_popup_enter(args)
end

SplashScreenCallbacks.cb_changelog_popup_item_selected = function (self, args)
	self._state:cb_changelog_popup_item_selected(args)
end

SplashScreenCallbacks.cb_goto_next_splash_screen = function (self)
	self._state:cb_goto_next_splash_screen()
end

SplashScreenCallbacks.cb_check_changelog = function (self)
	self._state:cb_check_changelog()
end

SplashScreenCallbacks.cb_goto_main_menu = function (self)
	self._state:cb_goto_main_menu()
end

SplashScreenCallbacks.cb_open_url_in_browser = function (self, url)
	Application.open_url_in_browser(url)
end
