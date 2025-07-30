package client

type Response struct {
	Proxies                Proxies          `json:"proxies"`
	Expire                 int64            `json:"expire"`
	DataLimit              int64            `json:"data_limit"` // Pointer to handle null
	DataLimitResetStrategy string           `json:"data_limit_reset_strategy"`
	Inbounds               Inbounds         `json:"inbounds"`
	Note                   string           `json:"note"`
	SubUpdatedAt           *string          `json:"sub_updated_at"`          // Pointer to handle null
	SubLastUserAgent       *string          `json:"sub_last_user_agent"`     // Pointer to handle null
	OnlineAt               *string          `json:"online_at"`               // Pointer to handle null
	OnHoldExpireDuration   *int             `json:"on_hold_expire_duration"` // Pointer to handle null
	OnHoldTimeout          string           `json:"on_hold_timeout"`
	AutoDeleteInDays       *int             `json:"auto_delete_in_days"` // Pointer to handle null
	Username               string           `json:"username"`
	Status                 string           `json:"status"`
	UsedTraffic            int64            `json:"used_traffic"`
	LifetimeUsedTraffic    int64            `json:"lifetime_used_traffic"`
	CreatedAt              string           `json:"created_at"`
	Links                  []string         `json:"links"`
	SubscriptionURL        string           `json:"subscription_url"`
	ExcludedInbounds       ExcludedInbounds `json:"excluded_inbounds"`
	Admin                  Admin            `json:"admin"`
}

type Proxies struct {
	VLESS Vless `json:"vless"`
}

type Vless struct {
	ID   string `json:"id"`
	Flow string `json:"flow"`
}

type Inbounds struct {
	VLESS []string `json:"vless"`
}

type ExcludedInbounds struct {
	VLESS []string `json:"vless"`
}

type Admin struct {
	Username       string  `json:"username"`
	IsSudo         bool    `json:"is_sudo"`
	TelegramID     int  `json:"telegram_id"`     // Pointer to handle null
	DiscordWebhook *string `json:"discord_webhook"` // Pointer to handle null
}