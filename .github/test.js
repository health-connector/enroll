import { sleep, group } from 'k6'
import http from 'k6/http'
import { URLSearchParams } from 'https://jslib.k6.io/url/1.0.0/index.js'

export const options = {
  ext: {
    loadimpact: {
      distribution: { 'amazon:us:ashburn': { loadZone: 'amazon:us:ashburn', percent: 100 } },
      apm: [],
    },
  },
  thresholds: {},
  scenarios: {
    Scenario_1: {
      executor: 'ramping-vus',
      gracefulStop: '30s',
      stages: [
        { target: 50, duration: '5m' },
        { target: 50, duration: '2m30s' },
        { target: 50, duration: '1m' },
      ],
      gracefulRampDown: '30s',
      exec: 'scenario_1',
    },
  },
}

export function scenario_1() {
  let response

  const vars = {}

  group('page_1 - https://pvt-enroll.mhc.hbxshop.org/', function () {
    response = http.get('https://pvt-enroll.mhc.hbxshop.org/', {
      headers: {
        'upgrade-insecure-requests': '1',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.8)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/favicon-d3bdef17493d637350fa0a4f0b4ce7ca.ico',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(2.9)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor',
      {
        headers: {
          accept: 'text/html, application/xhtml+xml, application/xml',
          'x-xhr-referer': 'https://pvt-enroll.mhc.hbxshop.org/',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    vars['user[referer]1'] = response.html().find('input[name=user[referer]]').first().attr('value')

    sleep(9)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/false-red-54ca56fc77295769f7876a0d49e05a4a.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.8)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/checkmark-green-d604fe9b74dea951b2860b57086cea91.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(7.6)
  })

  group('page_2 - https://pvt-enroll.mhc.hbxshop.org/users', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/users',
      {
        utf8: '✓',
        authenticity_token:
          'SDMx6cJDBApxqqjAK6iTGbm91rhlnxXOsl7hM4nf82AaszRJ5RLMc2hp4JJtIvcgFi5TaqxCFD2uDN0Z+rbcXg==',
        'user[referer]': 'https://pvt-enroll.mhc.hbxshop.org/',
        'user[oim_id]': 'test10@test.com',
        'user[password]': 'Testing123!',
        'user[password_confirmation]': 'Testing123!',
        'user[email]': '',
        'user[invitation_id]': '',
        commit: 'Create account',
      },
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    vars['utf81'] = response.html().find('input[name=utf8]').first().attr('value')

    vars['agency[profile_type]1'] = response
      .html()
      .find('input[name=agency[profile_type]]')
      .first()
      .attr('value')

    vars[
      'agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]1'
    ] = response
      .html()
      .find(
        'input[name=agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]]'
      )
      .first()
      .attr('value')

    sleep(0.6)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/benefit_sponsors/application-ba7113c9b571d5aa8b1a62bed58d4a12.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/benefit_sponsors/application-152aa25aac3771346dd4e77fa0610b68.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/benefit_sponsors-1a2315bd0b5baf9cde9a.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.5)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/generate_sic_tree',
      {
        headers: {
          accept: 'application/json, text/javascript, */*; q=0.01',
          'x-csrf-token':
            '5PodPRQrgj+jXFGZ3nbMUaebwSfh++7U9BWEeMXQcuC2ehidM3pKRrqfGcuY/KhoCAhE9Sgm7yfoR7hStrld3g==',
          'x-requested-with': 'XMLHttpRequest',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/favicon.ico', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })
    sleep(8)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui-icons-main-3b353884cc102ad533da5d0053cb0cc2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(32.7)

    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/registrations/counties_for_zip_code',
      '{"zip_code":"20871"}',
      {
        headers: {
          accept: 'application/json, text/plain, */*',
          'content-type': 'application/json; charset=UTF-8',
          'x-csrf-token':
            '5PodPRQrgj+jXFGZ3nbMUaebwSfh++7U9BWEeMXQcuC2ehidM3pKRrqfGcuY/KhoCAhE9Sgm7yfoR7hStrld3g==',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(6.6)

    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/registrations/counties_for_zip_code',
      '{"zip_code":"01001"}',
      {
        headers: {
          accept: 'application/json, text/plain, */*',
          'content-type': 'application/json; charset=UTF-8',
          'x-csrf-token':
            '5PodPRQrgj+jXFGZ3nbMUaebwSfh++7U9BWEeMXQcuC2ehidM3pKRrqfGcuY/KhoCAhE9Sgm7yfoR7hStrld3g==',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(7.9)
  })

  group(
    'page_3 - https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/registrations',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/registrations',
        {
          utf8: `${vars['utf81']}`,
          authenticity_token:
            '5PodPRQrgj+jXFGZ3nbMUaebwSfh++7U9BWEeMXQcuC2ehidM3pKRrqfGcuY/KhoCAhE9Sgm7yfoR7hStrld3g==',
          'agency[profile_type]': `${vars['agency[profile_type]1']}`,
          'agency[staff_roles_attributes][0][person_id]': '',
          'agency[staff_roles_attributes][0][first_name]': 'test10',
          'agency[staff_roles_attributes][0][last_name]': 'sam10',
          'agency[staff_roles_attributes][0][dob]': '11/11/1986',
          'agency[staff_roles_attributes][0][email]': 'test10@test.com',
          'agency[staff_roles_attributes][0][area_code]': '453',
          'agency[staff_roles_attributes][0][number]': '5647564',
          'agency[organization][legal_name]': 'fdsgdhn',
          'agency[organization][dba]': 'erwty',
          'agency[organization][fein]': '456435764',
          'agency[organization][entity_kind]': 'c_corporation',
          'agency[organization][profile_attributes][sic_code]': '0851',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][address_1]':
            '9377 lee hwy',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][kind]':
            'primary',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][address_2]':
            '',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][city]':
            'Clarksburg',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][state]':
            'MA',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][zip]':
            '01001',
          'agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][county]':
            'Hampden',
          'agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]': `${vars['agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]1']}`,
          'agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][area_code]':
            '251',
          'agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][number]':
            '2453646',
          'agency[organization][profile_attributes][referred_by]': 'Social media, such as Facebook',
          'agency[organization][profile_attributes][referred_reason]': '',
          'agency[organization][profile_attributes][contact_method]': 'electronic_only',
          commit: 'Confirm',
          employer_id: '',
        },
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.8)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/expertgreen_50-279fc6b6b28a9ce58cc4d7f5832e26fa.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/gearsgreen_50-1436eb2cbfbcb5252d6d02a7161a4913.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/connect_well-851a0b1b5349ce0d526c2ad6a449b1ce.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.8)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=home',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.7)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/new?tab=benefits',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.7)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/late_rates_check?start_on_date=06%2F01%2F2023',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              '5Edg52huQZgPSCFkV8LhdzW2QSnYaJHe50njzvvqIe22x2VHTz+J4RaLaTYRSIVOmiXE+xG1kC37G9/kiIMO0w==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(5.3)
    }
  )

  group(
    'page_4 - https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications',
        {
          utf8: `${vars['utf81']}`,
          authenticity_token:
            '5Edg52huQZgPSCFkV8LhdzW2QSnYaJHe50njzvvqIe22x2VHTz+J4RaLaTYRSIVOmiXE+xG1kC37G9/kiIMO0w==',
          'benefit_application[benefit_sponsorship_id]': '645ba70e608e772d82cb6720',
          'benefit_application[start_on]': '06/01/2023',
          'benefit_application[end_on]': '05/31/2024',
          'benefit_application[open_enrollment_start_on]': '05/10/2023',
          'benefit_application[open_enrollment_end_on]': '05/20/2023',
          'benefit_application[fte_count]': '10',
          'benefit_application[pte_count]': '10',
          'benefit_application[msp_count]': '10',
          commit: 'Continue',
        },
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(7.1)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(7.9)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employer_contributions?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employee_cost_details?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(3.6)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employer_contributions?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employee_cost_details?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(1.1)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employer_contributions?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employee_cost_details?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=0&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(1.2)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employer_contributions?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages/calculate_employee_cost_details?benefit_package%5Bbenefit_application_id%5D=645ba723608e772d7dcb7e75&benefit_package%5Btitle%5D=EWRGDHF&benefit_package%5Bdescription%5D=ERAWTSYJYH&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bkind%5D=health&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_option_choice%5D=5b46cd97aea91a61c766f196&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bid%5D=645ba725608e772d7dcb7ee1&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c791&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bdisplay_name%5D=Employee&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B1%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bid%5D=645ba725608e772d7dcb7ee2&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c793&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bdisplay_name%5D=Spouse&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B2%5D%5Bcontribution_factor%5D=90&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bid%5D=645ba725608e772d7dcb7ee3&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_unit_id%5D=5b117fc19f880b34354e4e72&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bdisplay_name%5D=Domestic+Partner&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B3%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bid%5D=645ba725608e772d7dcb7ee4&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_unit_id%5D=5b044e499f880b5d6f36c795&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bis_offered%5D=true&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bdisplay_name%5D=Child+Under+26&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bsponsor_contribution_attributes%5D%5Bcontribution_levels_attributes%5D%5B4%5D%5Bcontribution_factor%5D=95&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Bproduct_package_kind%5D=single_issuer&benefit_package%5Bsponsored_benefits_attributes%5D%5B0%5D%5Breference_plan_id%5D=635b386aaca7d412b10c8bc5',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(1.8)
    }
  )

  group(
    'page_5 - https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/benefit_packages',
        new URLSearchParams({
          utf8: `${vars['utf81']}`,
          _method: 'create',
          authenticity_token:
            'y7HRYoiVALYiedk93Kajvb1dfrh3vFWgH8/MgAnmoI+ZMdTCr8TIzzu6kW+aLMeEEs77ar5hVFMDnfCqeo+PsQ==',
          'benefit_package[benefit_application_id]': '645ba723608e772d7dcb7e75',
          'benefit_package[title]': 'EWRGDHF',
          'benefit_package[description]': 'ERAWTSYJYH',
          'benefit_package[probation_period_kind]': 'first_of_month',
          'benefit_package[sponsored_benefits_attributes][0][product_package_kind]':
            'single_issuer',
          'benefit_package[sponsored_benefits_attributes][0][kind]': [
            'health',
            'health',
            'health',
            'health',
            'health',
            'health',
          ],
          'benefit_package[sponsored_benefits_attributes][0][product_option_choice]':
            '5b46cd97aea91a61c766f196',
          'benefit_package[sponsored_benefits_attributes][0][reference_plan_id]':
            '635b386aaca7d412b10c8bc5',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][1][id]':
            '645ba725608e772d7dcb7ee1',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][1][contribution_unit_id]':
            '5b044e499f880b5d6f36c791',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][1][display_name]':
            'Employee',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][1][contribution_factor]':
            '95',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][2][id]':
            '645ba725608e772d7dcb7ee2',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][2][contribution_unit_id]':
            '5b044e499f880b5d6f36c793',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][2][is_offered]':
            'true',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][2][display_name]':
            'Spouse',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][2][contribution_factor]':
            '90',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][3][id]':
            '645ba725608e772d7dcb7ee3',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][3][contribution_unit_id]':
            '5b117fc19f880b34354e4e72',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][3][is_offered]':
            'true',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][3][display_name]':
            'Domestic Partner',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][3][contribution_factor]':
            '95',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][4][id]':
            '645ba725608e772d7dcb7ee4',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][4][contribution_unit_id]':
            '5b044e499f880b5d6f36c795',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][4][is_offered]':
            'true',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][4][display_name]':
            'Child Under 26',
          'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][4][contribution_factor]':
            '95',
          add_new_benefit_package: 'false',
        }).toString(),
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(3.7)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(5.2)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=employees',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.9)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/employers/employer_profiles/645ba70e608e772d82cb6721/census_employees/new?tab=employees',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=employees',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      vars['census_employee[address_attributes][kind]1'] = response
        .html()
        .find('input[name=census_employee[address_attributes][kind]]')
        .first()
        .attr('value')

      sleep(0.7)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/radiobutton_100-f79cf793551ab32b0963cac49c6de63e.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(16.5)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/jquery-ui/ui-icons_444444_256x240-6ac626f57196c790045bc80991f2c1ca.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(62.3)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/check_time_until_logout.js?_=1683728185532',
        {
          headers: {
            accept:
              'text/javascript, application/javascript, application/ecmascript, application/x-ecmascript, */*; q=0.01',
            'x-csrf-token':
              'd6C6qBCTsEOD+0yiE3iMH/GpjGaHnxx798doreEPpGElIL8IN8J4Opo4BPBV8ugmXjoJtE5CHYjrlVSHkmaLXw==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(5.7)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/check_time_until_logout.js?_=1683728185533',
        {
          headers: {
            accept:
              'text/javascript, application/javascript, application/ecmascript, application/x-ecmascript, */*; q=0.01',
            'x-csrf-token':
              'd6C6qBCTsEOD+0yiE3iMH/GpjGaHnxx798doreEPpGElIL8IN8J4Opo4BPBV8ugmXjoJtE5CHYjrlVSHkmaLXw==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(106.1)
    }
  )

  group(
    'page_6 - https://pvt-enroll.mhc.hbxshop.org/employers/employer_profiles/645ba70e608e772d82cb6721/census_employees?employer_id=645ba70e608e772d82cb6721',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/employers/employer_profiles/645ba70e608e772d82cb6721/census_employees?employer_id=645ba70e608e772d82cb6721',
        {
          utf8: `${vars['utf81']}`,
          authenticity_token:
            'd6C6qBCTsEOD+0yiE3iMH/GpjGaHnxx798doreEPpGElIL8IN8J4Opo4BPBV8ugmXjoJtE5CHYjrlVSHkmaLXw==',
          'census_employee[first_name]': 'harry',
          'census_employee[middle_name]': '',
          'census_employee[last_name]': 'emp10',
          'census_employee[name_sfx]': '',
          'census_employee[dob]': '1982-05-19',
          'jq_datepicker_ignore_census_employee[dob]': '05/19/1982',
          'census_employee[ssn]': '354-35-6456',
          'census_employee[gender]': 'male',
          'census_employee[hired_on]': '2023-05-01',
          'jq_datepicker_ignore_census_employee[hired_on]': '05/01/2023',
          'census_employee[is_business_owner]': '0',
          'census_employee[benefit_group_assignments_attributes][0][benefit_group_id]':
            '645ba737608e772d81cb7da9',
          'census_employee[cobra_begin_date]': '',
          'jq_datepicker_ignore_census_employee[cobra_begin_date]': '',
          'census_employee[address_attributes][kind]': 'home',
          'census_employee[address_attributes][address_1]': '9377 lee hwy',
          'census_employee[address_attributes][address_2]': '325',
          'census_employee[address_attributes][city]': 'Fairfax',
          'census_employee[address_attributes][state]': 'MA',
          'census_employee[address_attributes][zip]': '01001',
          'census_employee[email_attributes][kind]': 'home',
          'census_employee[email_attributes][address]': 'hemp10@test.com',
        },
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      vars['utf82'] = response.html().find('input[name=utf8]').first().attr('value')

      sleep(3.9)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(5.1)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=employees',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(4.1)

      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/submit_application',
        null,
        {
          headers: {
            accept:
              '*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript',
            'x-csrf-token':
              'YYPilN01GtIDwb50iHRP1TBKvMXGHRsKU0TlB2AblRIzA+c0+mTSqxoC9ibO/ivsn9k5Fw/AGvlPFtktE3K6LA==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(4.8)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=documents',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.9)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/employers/employer_profiles/645ba70e608e772d82cb6721/new_document?location_id=undefined',
        {
          headers: {
            accept:
              '*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript',
            'x-csrf-token':
              'OUeXZVY48c5yI3WSKnj5aCzTJDgs4iLNjBUG/xl4J+lrx5LFcWk5t2vgPcBs8p1Rg0Ch6uU/Iz6QRzrVahEI1w==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(15.4)
    }
  )

  group('page_7 - https://pvt-enroll.mhc.hbxshop.org/employers/employer_attestations', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/employers/employer_attestations',
      null,
      {
        headers: {
          'content-type': 'multipart/form-data; boundary=----WebKitFormBoundaryj4J6SFL0XUIcKJ9f',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1.7)
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.5)
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/document/download/mhc-enroll-attestations-preprod/593d3a4c-6d4f-43dd-9d2a-5db76975f639?id=645ba70e608e772d82cb6721&content_type=application/pdf&filename=WS52493772pdf&disposition=inline',
      {
        headers: {
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(4.1)
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
      {
        headers: {
          accept: 'text/html, application/xhtml+xml, application/xml',
          'x-xhr-referer':
            'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=documents',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(3.5)
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/benefit_sponsorships/645ba70e608e772d82cb6720/benefit_applications/645ba723608e772d7dcb7e75/submit_application',
      null,
      {
        headers: {
          accept:
            '*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript',
          'x-csrf-token':
            '/7zQiO/1WB7gUUwqvKhhk3yBInJnFnYY0qJpZaXVrN6tPNUoyKSQZ/mSBHj6IgWq0xKnoK7Ld+vO8FVP1ryD4A==',
          'x-requested-with': 'XMLHttpRequest',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1.6)
  })

  group(
    'page_8 - https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
    function () {
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721?tab=benefits',
        {
          headers: {
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(1)
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/icon-business-owner-dd238cdec812e79b78ae848008f8b230.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(7.4)
      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/benefit_sponsors/profiles/employers/employer_profiles/645ba70e608e772d82cb6721/estimate_cost?benefit_package_id=645ba737608e772d81cb7da9',
        {
          headers: {
            accept: '*/*',
            'x-csrf-token':
              '3O+qy3EF/Q0XfQZMPjyWUz2J5T8WLYzU9c+UfaANJ0KOb69rVlQ1dA6+Th54tvJqkhpg7d/wjSfpnahX02QIfA==',
            'x-requested-with': 'XMLHttpRequest',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(3.7)
    }
  )

  group('page_9 - https://pvt-enroll.mhc.hbxshop.org/users/sign_out', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/users/sign_out',
      {
        _method: 'delete',
        authenticity_token:
          '3O+qy3EF/Q0XfQZMPjyWUz2J5T8WLYzU9c+UfaANJ0KOb69rVlQ1dA6+Th54tvJqkhpg7d/wjSfpnahX02QIfA==',
      },
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(2.8)

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/insured/employee/privacy', {
      headers: {
        accept: 'text/html, application/xhtml+xml, application/xml',
        'x-xhr-referer': 'https://pvt-enroll.mhc.hbxshop.org/',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })
    sleep(2.8)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/false-red-54ca56fc77295769f7876a0d49e05a4a.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/checkmark-green-d604fe9b74dea951b2860b57086cea91.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(8.5)
  })

  group('page_10 - https://pvt-enroll.mhc.hbxshop.org/users', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/users',
      {
        utf8: `${vars['utf82']}`,
        authenticity_token:
          'yflSZb/bw99nbTxrm1EbAYVRC76zByLbKQkc2nUogB42qR2L3z+DK6qUyGuOFKE3lDhUjEnMT0OwnkMH2Ua6ZA==',
        'user[referer]': `${vars['user[referer]1']}`,
        'user[oim_id]': 'hemp10@test.com',
        'user[password]': 'Testing123!',
        'user[password_confirmation]': 'Testing123!',
        'user[email]': '',
        'user[invitation_id]': '',
        commit: 'Create account',
      },
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.5)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(10.1)

    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/users/645ba84b608e772d82cb672c/security_question_responses',
      new URLSearchParams({
        utf8: `${vars['utf82']}`,
        'security_question_responses[][security_question_id]': [
          '5992973daca7d42f2100000b',
          '5992973daca7d42f21000005',
          '5992973daca7d42f21000008',
        ],
        'security_question_responses[][question_answer]': ['a', 'a', 'a'],
        commit: 'Save Responses',
      }).toString(),
      {
        headers: {
          accept:
            '*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript',
          'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'x-csrf-token':
            'FI2KR5GlJXkFlgGeXaMpJCrcs+XtmCkp5SqjdOobRy/r3cWp8UFljchv9Z5I5pMSO7Xs1xdTRLF8vfypRnV9VQ==',
          'x-requested-with': 'XMLHttpRequest',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(3.2)

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/insured/employee/search', {
      headers: {
        accept: 'text/html, application/xhtml+xml, application/xml',
        'x-xhr-referer': 'https://pvt-enroll.mhc.hbxshop.org/insured/employee/privacy',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    vars['utf83'] = response.html().find('input[name=utf8]').first().attr('value')

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/check_radio_sheet-95d8fe381227f1e1d6dd4435c3e01b7c.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/lightgreenarrow_354-47807f393f358011e39dc6bef1f312b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(12.6)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui-icons-main-3b353884cc102ad533da5d0053cb0cc2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(8.7)
  })

  group('page_11 - https://pvt-enroll.mhc.hbxshop.org/insured/employee/match', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/insured/employee/match',
      {
        utf8: `${vars['utf82']}`,
        authenticity_token:
          'kt4GGDGpRTF5iPCU/qMDa3WwZJLW2XZmcVsa0R6zUJVtjkn2UU0FxbRxBJTr5rldZNk7oCwSG/7ozEUMst1q7w==',
        'people[id]': '',
        'person[first_name]': 'harry',
        'person[middle_name]': '',
        'person[last_name]': 'emp10',
        'person[name_sfx]': '',
        'person[dob]': '1982-05-19',
        'jq_datepicker_ignore_person[dob]': '05/19/1982',
        'person[ssn]': '354-35-6456',
        'person[gender]': 'male',
      },
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    vars['employment_relationship[first_name]1'] = response
      .html()
      .find('input[name=employment_relationship[first_name]]')
      .first()
      .attr('value')

    vars['employment_relationship[last_name]1'] = response
      .html()
      .find('input[name=employment_relationship[last_name]]')
      .first()
      .attr('value')

    vars['person[name_sfx]1'] = response
      .html()
      .find('input[name=person[name_sfx]]')
      .first()
      .attr('value')

    vars['employment_relationship[gender]1'] = response
      .html()
      .find('input[name=employment_relationship[gender]]')
      .first()
      .attr('value')

    vars['employment_relationship[hired_on]1'] = response
      .html()
      .find('input[name=employment_relationship[hired_on]]')
      .first()
      .attr('value')

    vars['employment_relationship[eligible_for_coverage_on]1'] = response
      .html()
      .find('input[name=employment_relationship[eligible_for_coverage_on]]')
      .first()
      .attr('value')

    vars['employment_relationship[census_employee_id]1'] = response
      .html()
      .find('input[name=employment_relationship[census_employee_id]]')
      .first()
      .attr('value')

    vars['person[dob]1'] = response.html().find('input[name=person[dob]]').first().attr('value')

    vars['person[ssn]1'] = response.html().find('input[name=person[ssn]]').first().attr('value')

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/lightgreenarrow_354-47807f393f358011e39dc6bef1f312b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/list-2e8c52fdfce3015576f5bc24c796cd39.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.7)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/check_radio_sheet-95d8fe381227f1e1d6dd4435c3e01b7c.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/radiobutton_100-f79cf793551ab32b0963cac49c6de63e.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1.9)
  })

  group('page_12 - https://pvt-enroll.mhc.hbxshop.org/insured/employee', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/insured/employee',
      {
        utf8: `${vars['utf83']}`,
        authenticity_token:
          'j1WCiNvC0zKfcuaESnuuAyJ4CKXUA5pWu+6TjC2tTX5wBc1muyaTxlKLEoRfPhQ1MxFXly7I984iecxRgcN3BA==',
        'employment_relationship[first_name]': `${vars['employment_relationship[first_name]1']}`,
        'employment_relationship[last_name]': `${vars['employment_relationship[last_name]1']}`,
        'employment_relationship[middle_name]': `${vars['person[name_sfx]1']}`,
        'employment_relationship[name_pfx]': `${vars['person[name_sfx]1']}`,
        'employment_relationship[name_sfx]': `${vars['person[name_sfx]1']}`,
        'employment_relationship[gender]': `${vars['employment_relationship[gender]1']}`,
        'employment_relationship[hired_on]': `${vars['employment_relationship[hired_on]1']}`,
        'employment_relationship[eligible_for_coverage_on]': `${vars['employment_relationship[eligible_for_coverage_on]1']}`,
        'employment_relationship[census_employee_id]': `${vars['employment_relationship[census_employee_id]1']}`,
      },
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.7)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-icon-individual-9965d1050dd7e4b33faaf1cc5142f8b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/lightgreenarrow_354-47807f393f358011e39dc6bef1f312b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/list-2e8c52fdfce3015576f5bc24c796cd39.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/check_radio_sheet-95d8fe381227f1e1d6dd4435c3e01b7c.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1.2)
  })

  group(
    'page_13 - https://pvt-enroll.mhc.hbxshop.org/insured/employee/645ba871608e772d7dcb7ef3',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/insured/employee/645ba871608e772d7dcb7ef3',
        {
          utf8: `${vars['utf83']}`,
          _method: 'put',
          authenticity_token:
            'u0tqDMaXbHorMrk2axtJuP+AWZTywg8GAnrbKzYXw8REGyXipnMsjubLTTZ+XvOO7ukGpggJYp6b7YT2mnn5vg==',
          exit_after_method: 'false',
          'person[employee_role_id]': '645ba871608e772d7dcb7ef8',
          'people[id]': `${vars['person[name_sfx]1']}`,
          'person[first_name]': `${vars['employment_relationship[first_name]1']}`,
          'person[middle_name]': `${vars['person[name_sfx]1']}`,
          'person[last_name]': `${vars['employment_relationship[last_name]1']}`,
          'person[name_sfx]': `${vars['person[name_sfx]1']}`,
          'person[dob]': `${vars['person[dob]1']}`,
          'person[ssn]': `${vars['person[ssn]1']}`,
          'person[gender]': `${vars['employment_relationship[gender]1']}`,
          'person[addresses_attributes][0][kind]': `${vars['census_employee[address_attributes][kind]1']}`,
          'person[addresses_attributes][0][address_1]': '9377 lee hwy',
          'person[addresses_attributes][0][address_2]': '325',
          'person[addresses_attributes][0][city]': 'Fairfax',
          'person[addresses_attributes][0][state]': 'MA',
          'person[addresses_attributes][0][zip]': '01001',
          'person[addresses_attributes][0][id]': '645ba800608e772d7ecb66d9',
          'person[addresses_attributes][1][kind]': `${vars['agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]1']}`,
          'person[addresses_attributes][1][address_1]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][1][address_2]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][1][city]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][1][state]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][1][zip]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][2][kind]': 'mailing',
          'person[addresses_attributes][2][address_1]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][2][address_2]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][2][city]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][2][state]': `${vars['person[name_sfx]1']}`,
          'person[addresses_attributes][2][zip]': `${vars['person[name_sfx]1']}`,
          'person[phones_attributes][0][kind]': `${vars['census_employee[address_attributes][kind]1']}`,
          'person[phones_attributes][0][_destroy]': 'false',
          'person[phones_attributes][0][full_phone_number]': `${vars['person[name_sfx]1']}`,
          'person[phones_attributes][1][kind]': 'mobile',
          'person[phones_attributes][1][_destroy]': 'false',
          'person[phones_attributes][1][full_phone_number]': `${vars['person[name_sfx]1']}`,
          'person[phones_attributes][2][kind]': `${vars['agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]1']}`,
          'person[phones_attributes][2][_destroy]': 'false',
          'person[phones_attributes][2][full_phone_number]': `${vars['person[name_sfx]1']}`,
          'person[phones_attributes][3][kind]': 'fax',
          'person[phones_attributes][3][_destroy]': 'false',
          'person[phones_attributes][3][full_phone_number]': `${vars['person[name_sfx]1']}`,
          'person[emails_attributes][0][kind]': `${vars['census_employee[address_attributes][kind]1']}`,
          'person[emails_attributes][0][_destroy]': 'false',
          'person[emails_attributes][0][address]': 'hemp10@test.com',
          'person[emails_attributes][0][id]': '645ba871608e772d7dcb7ef7',
          'person[emails_attributes][1][kind]': `${vars['agency[organization][profile_attributes][office_locations_attributes][0][phone_attributes][kind]1']}`,
          'person[emails_attributes][1][_destroy]': 'false',
          'person[emails_attributes][1][address]': 'hemp10@test.com',
          'person[emails_attributes][1][id]': '645ba872608e772d7dcb7f02',
          'person[employee_roles_attributes][0][id]': '645ba871608e772d7dcb7ef8',
          'person[employee_roles_attributes][0][contact_method]':
            'Paper and Electronic communications',
          'person[employee_roles_attributes][0][language_preference]': 'English',
        },
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-icon-individual-9965d1050dd7e4b33faaf1cc5142f8b2.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/lightgreenarrow_354-47807f393f358011e39dc6bef1f312b2.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/list-2e8c52fdfce3015576f5bc24c796cd39.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.5)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/insured/members_selections/new?change_plan=&change_plan_date=&employee_role_id=645ba871608e772d7dcb7ef8&event=shop_for_plans&person_id=645ba871608e772d7dcb7ef3',
        {
          headers: {
            accept: 'text/html, application/xhtml+xml, application/xml',
            'x-xhr-referer':
              'https://pvt-enroll.mhc.hbxshop.org/insured/family_members?employee_role_id=645ba871608e772d7dcb7ef8',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.7)
    }
  )

  group('page_14 - https://pvt-enroll.mhc.hbxshop.org/insured/members_selections', function () {
    response = http.post(
      'https://pvt-enroll.mhc.hbxshop.org/insured/members_selections',
      new URLSearchParams({
        utf8: `${vars['utf83']}`,
        authenticity_token:
          'zyl5n4jSy5Kgc1GD7CvkpQMHknBD9tUswrJ0R4zt+0AweTZx6DaLZm2KpYP5bl6TEm7NQrk9uLRbJSuaIIPBOg==',
        employee_role_id: ['645ba871608e772d7dcb7ef8', '645ba871608e772d7dcb7ef8'],
        event: 'shop_for_plans',
        waiver_reason: [`${vars['person[name_sfx]1']}`, `${vars['person[name_sfx]1']}`],
        is_waiving: `${vars['person[name_sfx]1']}`,
        person_id: '645ba871608e772d7dcb7ef3',
        coverage_household_id: '645ba871608e772d7dcb7efc',
        enrollment_kind: `${vars['person[name_sfx]1']}`,
        'family_member_ids[0]': '645ba871608e772d7dcb7efe',
        'shopping_members[health][645ba871608e772d7dcb7efe]': 'enroll',
        market_kind: 'shop',
        change_plan: `${vars['person[name_sfx]1']}`,
        commit: 'Confirm your Selections',
      }).toString(),
      {
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          origin: 'https://pvt-enroll.mhc.hbxshop.org',
          'upgrade-insecure-requests': '1',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(1.3)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-icon-individual-9965d1050dd7e4b33faaf1cc5142f8b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/ui/lightgreenarrow_354-47807f393f358011e39dc6bef1f312b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/logo/carrier/blue_cross_blue_shield_ma-02c10bf2d80b91c2c602c7fffd9eacf2.jpg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.7)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/silver-circle-6c9c2f9ad46e59142efbc592b679d4bc.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/gold-circle-36ad9e6886bf498672fd8e56e6911358.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/platinum-circle-3eced19c78dc5ce5fdc12b8129ba01ce.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(2.6)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/insured/product_shoppings/continuous_show?cart%5Bhealth%5D%5Bid%5D=645ba87a608e772d7dcb7f04&cart%5Bhealth%5D%5Bproduct_id%5D=635b386aaca7d412b10c8cfe&dental_offering=false&event=shop_for_plans&health%5Bchange_plan%5D=&health%5Benrollment_id%5D=645ba87a608e772d7dcb7f04&health%5Benrollment_kind%5D=&health%5Bmarket_kind%5D=employer_sponsored&health%5Bselected_to_waive%5D=false&health%5Bwaiver_reason%5D=&health_offering=true',
      {
        headers: {
          accept: 'text/html, application/xhtml+xml, application/xml',
          'x-xhr-referer':
            'https://pvt-enroll.mhc.hbxshop.org/insured/product_shoppings/continuous_show?dental_offering=false&event=shop_for_plans&health%5Bchange_plan%5D=&health%5Benrollment_id%5D=645ba87a608e772d7dcb7f04&health%5Benrollment_kind%5D=&health%5Bmarket_kind%5D=employer_sponsored&health%5Bselected_to_waive%5D=false&health%5Bwaiver_reason%5D=&health_offering=true',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.5)

    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/list-2e8c52fdfce3015576f5bc24c796cd39.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(2.1)
  })

  group(
    'page_15 - https://pvt-enroll.mhc.hbxshop.org/insured/product_shoppings/checkout?health%5Bcoverage_kind%5D=health&health%5Bemployee_role_id%5D=645ba871608e772d7dcb7ef8&health%5Benrollable%5D=true&health%5Benrollment_id%5D=645ba87a608e772d7dcb7f04&health%5Benrollment_kind%5D=open_enrollment&health%5Bevent%5D=shop_for_plans&health%5Bfamily_id%5D=645ba871608e772d7dcb7f00&health%5Bmarket_kind%5D=employer_sponsored&health%5Bproduct_id%5D=635b386aaca7d412b10c8cfe&health%5Buse_family_deductable%5D=true&health%5Bwaivable%5D=true&health%5Bwaiver_reason%5D=',
    function () {
      response = http.post(
        'https://pvt-enroll.mhc.hbxshop.org/insured/product_shoppings/checkout?health%5Bcoverage_kind%5D=health&health%5Bemployee_role_id%5D=645ba871608e772d7dcb7ef8&health%5Benrollable%5D=true&health%5Benrollment_id%5D=645ba87a608e772d7dcb7f04&health%5Benrollment_kind%5D=open_enrollment&health%5Bevent%5D=shop_for_plans&health%5Bfamily_id%5D=645ba871608e772d7dcb7f00&health%5Bmarket_kind%5D=employer_sponsored&health%5Bproduct_id%5D=635b386aaca7d412b10c8cfe&health%5Buse_family_deductable%5D=true&health%5Bwaivable%5D=true&health%5Bwaiver_reason%5D=',
        {
          _method: 'post',
          authenticity_token:
            't/Ky4okfsDe17goQOlSn1i5pfcOoR/gY7KmIt5Van3xIov0M6fvww3gX/hAvER3gPwAi8VKMlYB1PtdqOTSlBg==',
        },
        {
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            origin: 'https://pvt-enroll.mhc.hbxshop.org',
            'upgrade-insecure-requests': '1',
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(0.8)

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-9d715d715b2e70f4c8471e4953c82037.css',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/glossary-f2ea8fae7c6042bb08f1d87e47faa900.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/sponsored_benefits/application-f43446d71f861d86d34936129d48c427.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/ui_components-b30fd237011680283118.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-icon-individual-9965d1050dd7e4b33faaf1cc5142f8b2.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/profilegreen_37-1d668b137aed94d77db88578dc0e5f3b.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/darkgreenarrow_354-fc37a396263030172606c6a557627031.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/cartgreen_40-23767ac33e267084436cf3bf4a3a9cc8.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )

      response = http.get(
        'https://pvt-enroll.mhc.hbxshop.org/assets/ui/pointergreen_42-d43f4c7257e9ce282489e206deec4aff.png',
        {
          headers: {
            'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
          },
        }
      )
      sleep(2.3)

      response = http.get('https://pvt-enroll.mhc.hbxshop.org/families/home', {
        headers: {
          accept: 'text/html, application/xhtml+xml, application/xml',
          'x-xhr-referer':
            'https://pvt-enroll.mhc.hbxshop.org/insured/product_shoppings/receipt?health%5Bcan_select_coverage%5D=06%2F01%2F2023+00%3A00&health%5Bcoverage_kind%5D=health&health%5Bemployee_is_shopping_before_hire%5D=false&health%5Benrollment_id%5D=645ba87a608e772d7dcb7f04&health%5Bevent%5D=shop_for_plans&health%5Bproduct_id%5D=635b386aaca7d412b10c8cfe&health%5Bqle%5D=false',
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      })
      sleep(0.5)
    }
  )

  group('page_16 - https://pvt-enroll.mhc.hbxshop.org/families/home', function () {
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/connect_well-851a0b1b5349ce0d526c2ad6a449b1ce.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/logo/carrier/blue_cross_blue_shield_ma-02c10bf2d80b91c2c602c7fffd9eacf2.jpg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/shop_for_plan-fe32baec5e5e53e85790807393baaab5.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-life-event-1e125b31a0be62c1b09bb1c7dd617756.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get('https://pvt-enroll.mhc.hbxshop.org/families/home', {
      headers: {
        'upgrade-insecure-requests': '1',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })
    sleep(0.6)
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-7cca454f424417b3c82b35fedae753d1.css',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/application-09b46665ee58b0a7c2870790b8c88cd5.js',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get('https://pvt-enroll.mhc.hbxshop.org/packs/legacy-8e8c18e54fbaeeae6c99.js', {
      headers: {
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      },
    })
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/mhc_logo-6289d813827e25f5d3efca0a8a74f793.svg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-icon-individual-9965d1050dd7e4b33faaf1cc5142f8b2.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/logo/carrier/blue_cross_blue_shield_ma-02c10bf2d80b91c2c602c7fffd9eacf2.jpg',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/shop_for_plan-fe32baec5e5e53e85790807393baaab5.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/connect_well-851a0b1b5349ce0d526c2ad6a449b1ce.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/cca-life-event-1e125b31a0be62c1b09bb1c7dd617756.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
    sleep(0.9)
    response = http.get(
      'https://pvt-enroll.mhc.hbxshop.org/assets/icons/silver-circle-6c9c2f9ad46e59142efbc592b679d4bc.png',
      {
        headers: {
          'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"macOS"',
        },
      }
    )
  })
}
