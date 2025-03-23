package main

import "curl"
import "core:fmt"
import "core:mem"
import "core:c"
import runtime "base:runtime"
import "core:os"
import json "core:encoding/json"
import time "core:time"
import strings "core:strings"

Size: uint = 0
ZoneUrl :: "https://api.waktusolat.app/zones"
PrayerUrl :: "https://api.waktusolat.app/v2/solat"

Zones :: []struct {
    JakimCode: string `json:"jakimCode"`,
    Negeri:    string `json:"negeri"`,
    Daerah:    string `json:"daerah"`,
}

Prayer :: struct {
    Zone:string `json:"zone"`,
    Year:int    `json:"year"`,
    Month:string`json:"month"`,
    LastUpdated:string `json:"last_updated"`,

    Prayers :[]struct {
        Day :i64      `json:"day"`,
        Asr :i64      `json:"asr"`,
        Maghrib :i64  `json:"maghrib"`,
        Dhuhr :i64    `json:"dhuhr"`,
        Hijri :string `json:"hijri"`,
        Isha :i64     `json:"isha"`,
        Fajr :i64     `json:"fajr"`,
        Syuruk :i64   `json:"syuruk"`,
    } `json:"prayers"`
}


main :: proc() {
    length := len(os.args)

    if length < 2 {
        fmt.eprintfln("Usage: %s -zone | -time <zone>", "prayer")
        os.exit(1)
    }

    cmd := os.args[1]

    switch cmd {
        case "-zone":
            fetchZones()

        case "-time":
            if length < 3 {
                fmt.eprintfln("Usage: %s -time <zone>", "prayer")
                os.exit(1)
            }

            zone := os.args[2]
            fetchPrayers(zone)
    }

}

fetchPrayers :: proc(zone: string) {
    http_response, err:= mem.alloc(1)
    assert(err == nil, "Failed to allocate memory")
    defer free(http_response)

    c := curl.easy_init()
    defer curl.easy_cleanup(c)

    prayer_url := fmt.tprintf("%s/%s", PrayerUrl, zone)

    curl.easy_setopt(c, curl.Option.URL, prayer_url)
    curl.easy_setopt(c, curl.Option.Httpget, 1)
    curl.easy_setopt(c, curl.Option.Writedata, &http_response)
    curl.easy_setopt(c, curl.Option.Writefunction, write_callback)

    if res := curl.easy_perform(c); res != curl.Code.Ok {
        fmt.eprintfln("Could not fetch http_response from Jakim: %d", res)
        os.exit(1)
    }

    response := (cast([^]byte)http_response)[:Size]
    prayer := Prayer{}

    if err:= json.unmarshal(response, &prayer); err != nil {
        fmt.eprintfln("Could not unmarshall http response", err)
        os.exit(1)
    }

    fmt.println("+-----+------------+------------+------------+------------+------------+-------------+")
    fmt.printfln("|                                     %s                                          |", prayer.Zone)
    fmt.println("+-----+----------+----------+----------+----------+----------+----------+------------+")
    fmt.println("| Day | Fajr     | Syuruk   | Dhuhr    | Asr      | Maghrib  | Isha     | Hijri      |")
    fmt.println("+-----+----------+----------+----------+----------+----------+----------+------------+")


    for k in prayer.Prayers {
        fajr := time.unix(k.Fajr,0)
        fajr = time.time_add(fajr,time.Hour * 8)
        fajr_time := time.time_to_string_hms(fajr, make([]u8, 9))

        syuruk := time.unix(k.Syuruk,0)
        syuruk = time.time_add(syuruk,time.Hour * 8)
        syuruk_time := time.time_to_string_hms(syuruk, make([]u8, 9))

        dhuhr := time.unix(k.Dhuhr,0)
        dhuhr = time.time_add(dhuhr,time.Hour * 8)
        dhuhr_time := time.time_to_string_hms(dhuhr, make([]u8, 9))

        asr := time.unix(k.Asr,0)
        asr = time.time_add(asr,time.Hour * 8)
        asr_time := time.time_to_string_hms(asr, make([]u8, 9))

        maghrib := time.unix(k.Maghrib,0)
        maghrib = time.time_add(maghrib,time.Hour * 8)
        maghrib_time := time.time_to_string_hms(maghrib, make([]u8, 9))

        isha := time.unix(k.Isha,0)
        isha = time.time_add(isha,time.Hour * 8)
        isha_time := time.to_string_hms(isha, make([]u8, 9))

        day := fmt.tprintf("%d", k.Day)

        local_time := time.to_string_dd_mm_yy(time.now(), make([]u8, 11))
        local_time_parts :=strings.split(local_time, "-")
        current_day := local_time_parts[0]

        if day == current_day {
            fmt.println("+-----+----------+----------+----------+----------+----------+----------+------------+")
        }

        fmt.printfln("| %-4s| %-9s| %-9s| %-9s| %-9s| %-9s| %-9s| %-11s|", day, fajr_time, syuruk_time, dhuhr_time, asr_time, maghrib_time, isha_time, k.Hijri)

        if day == current_day {
            fmt.println("+-----+----------+----------+----------+----------+----------+----------+------------+")
        }
    }

   fmt.println("+-----+------------+------------+------------+------------+------------+-------------+")
}

fetchZones :: proc() {
    http_response, err:= mem.alloc(1)
    assert(err == nil, "Failed to allocate memory")
    defer free(http_response)

    c := curl.easy_init()
    defer curl.easy_cleanup(c)

    curl.easy_setopt(c, curl.Option.URL, ZoneUrl)
    curl.easy_setopt(c, curl.Option.Httpget, 1)
    curl.easy_setopt(c, curl.Option.Writedata, &http_response)
    curl.easy_setopt(c, curl.Option.Writefunction, write_callback)

    if res := curl.easy_perform(c); res != curl.Code.Ok {
        fmt.eprintfln("Could not fetch http_response from Jakim: %d", res)
        os.exit(1)
    }

    zones := Zones{}
    response := (cast([^]byte)http_response)[:Size]

    if err:= json.unmarshal(response, &zones); err != nil {
        fmt.eprintfln("Could not unmarshall http response", err)
        os.exit(1)
    }

    fmt.println("+-------+---------------------+---------------------------------------------------------------------------------------------------+")
    fmt.printfln("| Code  | Negeri              | %-98s|","Daerah")
    fmt.println("+-------+---------------------+---------------------------------------------------------------------------------------------------+")

    for z in zones {
        fmt.printfln("| %-6s| %-20s| %-98s|", z.JakimCode, z.Negeri, z.Daerah)
    }

    fmt.println("+-------+---------------------+---------------------------------------------------------------------------------------------------+")
}


write_callback :: proc "c" (ptr: [^]byte, size, nmemb: c.size_t, data: ^rawptr) -> c.size_t {
    initSize := Size
    response_size := size * nmemb
    context = runtime.default_context()

    err :mem.Allocator_Error
    data^, err  = mem.resize(data^, int(initSize), int(initSize + response_size))
    assert(err == nil, "Failed to resize memory")

    // cast to multi pointer so we can index it
    ptr_data := cast([^]byte)data^
    mem.copy(ptr_data[initSize:], ptr, cast(int)response_size)
    Size += response_size

    return response_size
}
