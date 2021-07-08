#!/bin/bash
# When PYSETUP_TEST_EXTRAS is not enabled, do not allow the
# default 'install' step to install all dependencies listed in
# requirements.txt to verify that a minimal install works as expected.
# Instead install requests in the before_script step below.
if [[ "$PYSETUP_TEST_EXTRAS" != '1' ]]; then 
  printf "# Empty requirements with PYSETUP_TEST_EXTRA" > requirements.txt ;
fi

# PYTEST is taken as the default
if [[ "$PYSETUP_TEST_EXTRAS" != '1' ]]; then
  export USE_PYTEST=1 ;
fi

if [[ "$PYWIKIBOT_SITE_ONLY" == "1" ]]; then
  echo "Running site tests only code ${LANGUAGE} on family ${FAMILY}" ;
fi

export GITHUB_USER=`echo $TRAVIS_REPO_SLUG | cut -d '/' -f 1`
mkdir ~/.python-eggs
chmod 700 ~/.python-eggs

if [[ "$GITHUB_USER" != "wikimedia" ]]; then
  export PYWIKIBOT_TEST_WRITE_FAIL=1 ;
fi

# Install dependencies
pip install -U setuptools
pip install -r dev-requirements.txt
pip install -r requirements.txt
pip install mwparserfromhell
if [[ "$PYSETUP_TEST_EXTRAS" != '1' ]]; then
  pip install -e .[mwoauth];
fi

mkdir ~/.pywikibot

python pwb.py generate_family_file 'https://wiki.musicbrainz.org/' musicbrainz 'n'
if [[ $FAMILY == 'wpbeta' ]]; then
  python -m generate_family_file 'http://'$LANGUAGE'.wikipedia.beta.wmflabs.org/' 'wpbeta' 'y' ;
fi
if [[ $FAMILY == 'wsbeta' ]]; then
  python -m generate_family_file 'http://'$LANGUAGE'.wikisource.beta.wmflabs.org/' 'wsbeta' 'y' ;
fi
if [[ $FAMILY == 'portalwiki' ]]; then
  python -m generate_family_file 'https://theportalwiki.com/wiki/Main_Page' 'portalwiki' 'y' 'y';
fi

python -W error::UserWarning -m generate_user_files -dir:~/.pywikibot/ -family:$FAMILY -lang:$LANGUAGE -v -user:"$PYWIKIBOT_USERNAME"

if [[ -n "$USER_PASSWORD" && -n "$PYWIKIBOT_USERNAME" ]]; then
  printf "usernames['wikipedia']['en'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "usernames['wikipedia']['test'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "usernames['wikidata']['test'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "usernames['commons']['commons'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "usernames['meta']['meta'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "usernames['wikisource']['zh'] = '%q'\n" "$PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  printf "('%q', '%q')\n" "$PYWIKIBOT_USERNAME" "$USER_PASSWORD" > ~/.pywikibot/passwordfile ;
  echo "import os" >> ~/.pywikibot/user-config.py ;
  echo "password_file = os.path.expanduser('~/.pywikibot/passwordfile')" >> ~/.pywikibot/user-config.py ;
fi

if [[ -n "$OAUTH_DOMAIN" ]]; then
  if [[ -n "$OAUTH_PYWIKIBOT_USERNAME" ]]; then
    printf "usernames['${FAMILY}']['${LANGUAGE}'] = '%q'\n" "$OAUTH_PYWIKIBOT_USERNAME" >> ~/.pywikibot/user-config.py ;
  fi ;
  oauth_token_var="OAUTH_TOKENS_${FAMILY^^}_${LANGUAGE^^}" ;
  if [[ -n "${!oauth_token_var}" ]]; then
    printf "authenticate['${OAUTH_DOMAIN}'] = ('%s')\n" "${!oauth_token_var//:/\', \'}" >> ~/.pywikibot/user-config.py ;
  fi ;
fi
echo "authenticate['wiki.musicbrainz.org'] = ('NOTSPAM', 'NOTSPAM')" >> ~/.pywikibot/user-config.py ;

echo "max_retries = 3" >> ~/.pywikibot/user-config.py
echo "maximum_GET_length = 5000" >> ~/.pywikibot/user-config.py
echo "console_encoding = 'utf8'" >> ~/.pywikibot/user-config.py

python -c "import setuptools; print(setuptools.__version__)"

if [[ "$USE_PYTEST" == "1" ]]; then
  if [[ "$PYWIKIBOT_SITE_ONLY" == "1" ]]; then
    python setup.py pytest --addopts="-vvv -s --timeout=$TEST_TIMEOUT --cov=. -rsxX -a \"family=='$FAMILY' and code=='$LANGUAGE'\"" ;
  else
    python setup.py pytest --addopts="-vvv -s --timeout=$TEST_TIMEOUT --cov=. -rsxX" ;
  fi
else
  coverage run -m unittest discover -vv -p "*_tests.py" ;
fi
