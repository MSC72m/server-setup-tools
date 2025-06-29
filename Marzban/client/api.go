package client

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"
)

type Marzban interface {
	CreateMarzbanUser(userID string, dataLimit int, dateLimit string) (Response, error)
}

type marzban struct{}

func NewMarzbanClient() Marzban {
	return &marzban{}
}

func (m *marzban) CreateMarzbanUser(username string, dataLimit int, dateLimit string) (Response, error) {
	expireTime := fmt.Sprint(CreateTime(dateLimit))
	limit := strconv.Itoa(GenerateData(dataLimit))
	var resp *http.Response
	var response Response

	token, err := auth()
	if err != nil {
		return response, err
	}

	data := strings.NewReader(`{
	  "username": ` + username + `,
	  "proxies": {
	    "vless": ""
	  },
	  "expire": ` + expireTime + `,
	  "data_limit": ` + limit + `,
	  "data_limit_reset_strategy": "no_reset",
	  "status": "active",
	  "note": "",
	  "on_hold_timeout": "2023-11-03T20:30:00",
	  "on_hold_expire_duration": 0
	}`)
	req, err := http.NewRequest("POST", API_CREATE_USER, data)
	if err != nil {
		return response, err
	}

	req.Header.Set("accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{}
	resp, err = client.Do(req)
	if resp == nil {
		return response, errors.New("FAILED REQUEST | " + API_CREATE_USER)
	}
	if err != nil {
		return response, err
	}

	body, _ := io.ReadAll(resp.Body)
	err = json.Unmarshal(body, &response)
	if err != nil {
		log.Println(err)
	}

	defer func(Body io.ReadCloser) {
		err := Body.Close()
		if err != nil {
			log.Println(err)
		}
	}(resp.Body)

	return response, nil
}

func auth() (string, error) {
	var resp *http.Response
	payload := strings.NewReader(`grant_type=&username=admin&password=admin&scope=&client_id=&client_secret=`)
	req, err := http.NewRequest("POST", API_AUTH_URL, payload)
	if err != nil {
		return "", err
	}

	client := http.Client{}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("accept", "application/json")

	resp, _ = client.Do(req)

	if resp == nil {
		return "", errors.New("nil response")
	}
	var jsonData Token

	err = json.NewDecoder(resp.Body).Decode(&jsonData)
	if err != nil {
		return "", err
	}
	defer func(Body io.ReadCloser) {
		err := Body.Close()
		if err != nil {
			log.Println(err)
		}
	}(resp.Body)

	return jsonData.AccessToen, nil
}

func CreateTime(month string) int64 {
	now := time.Now()
	var futureDate time.Time

	if month == "1" {
		futureDate = now.AddDate(0, 1, 0)
	}
	if month == "2" {
		futureDate = now.AddDate(0, 2, 0)
	}
	if month == "3" {
		futureDate = now.AddDate(0, 3, 0)
	}
	if month == "4" {
		futureDate = now.AddDate(0, 4, 0)
	}
	if month == "5" {
		futureDate = now.AddDate(0, 5, 0)
	}
	if month == "6" {
		futureDate = now.AddDate(0, 6, 0)
	}

	timestamp := time.Date(futureDate.Year(), futureDate.Month(), futureDate.Day(), 0, 0, 0, 0, time.UTC)

	t := timestamppb.New(timestamp).Seconds
	return t
}

func GenerateData(dataLimit int) int {
	if dataLimit == 10 {
		return DATA_LIMIT_10GB
	}

	if dataLimit == 15 {
		return DATA_LIMIT_15GB
	}

	if dataLimit == 20 {
		return DATA_LIMIT_20GB
	}

	if dataLimit == 30 {
		return DATA_LIMIT_30GB
	}

	if dataLimit == 40 {
		return DATA_LIMIT_40GB
	}

	if dataLimit == 60 {
		return DATA_LIMIT_60GB
	}

	if dataLimit == 70 {
		return DATA_LIMIT_70GB
	}

	if dataLimit == 80 {
		return DATA_LIMIT_80GB
	}

	if dataLimit == 90 {
		return DATA_LIMIT_90GB
	}

	if dataLimit == 50 {
		return DATA_LIMIT_50GB
	}

	if dataLimit == 100 {
		return DATA_LIMIT_100GB
	}

	return 0
}