import time
import os
import glob
import sys
import shutil
from selenium import webdriver
from selenium.webdriver.firefox.service import Service as FirefoxService
from webdriver_manager.firefox import GeckoDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.firefox.options import Options as SeleniumOptions
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser("Download the GSD metadata")

    parser.add_argument("outfile", type=str,
                        help="output, location to save the metadata to.")


    args = parser.parse_args()
        
    if not (os.path.exists(".secret/gsduser") and os.path.exists(".secret/gsdpass")):
        print ("you need to create a 'gsduser' and 'gsdpass' file inside of the .secret folder at root of this repo. ")
        print ("gsduser should contain the username and gsdpass should contain pass.")
        print ("remeber to not push them into git.")
        sys.exit("User/Pass not found.")

    options = SeleniumOptions()
    options.headless = False
    #This script is a shall identify legit computer :)
    options.set_preference("general.useragent.override","Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0") 
    options.set_preference("dom.webdriver.enabled", False) 
    options.set_preference('useAutomationExtension', False)
    #force download to go to PWD    
    options.set_preference("browser.download.folderList", 2) 
    options.set_preference("browser.download.manager.showWhenStarting", False)
    options.set_preference("browser.download.dir", os.getcwd())
    options.set_preference("browser.helperApps.neverAsk.saveToDisk", True)
    
    print("Connecting to GSD...")
    driver = webdriver.Firefox(options=options, service=FirefoxService(GeckoDriverManager().install()))
    queryLink = "https://www.epicov.org/epi3/frontend"
    driver.get(queryLink)
    time.sleep(2)
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.ID, "elogin")))
    time.sleep(1)
    username = driver.find_element(By.ID, "elogin")
    password = driver.find_element(By.ID, "epassword")


    with open (".secret/gsduser", 'r') as fh:
        user = fh.readline()
    with open (".secret/gsdpass", 'r') as fh:
        pswd = fh.readline()

    username.send_keys(user)
    password.send_keys(pswd)
    time.sleep(2)
    submit = driver.find_element(By.CLASS_NAME, "form_button_submit").click()
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.CLASS_NAME, "sys-actionbar-action-ni"))) 
    time.sleep(1)
    downloadButtons = driver.find_elements(By.CLASS_NAME, 'sys-actionbar-action-ni')
    downloadButton = [x for x in downloadButtons if x.text == "Downloads"][0]
    downloadButton.click()

    #first iframe for the datadownload popup
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.XPATH, "//*[starts-with(@id, 'sysoverlay-wid')]")))
    time.sleep(2)
    iframe = driver.find_element(By.XPATH, "//*[starts-with(@id, 'sysoverlay-wid')]")
    driver.switch_to.frame(iframe)
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.CLASS_NAME, 'downicon')))
    time.sleep(1)
    downloadButtons = driver.find_elements(By.CLASS_NAME, 'downicon')
    downloadButton = [x for x in downloadButtons if x.text == "metadata"][0]
    downloadButton.click()

    #another iframe for the agreement checkbox
    #2024/11/26 Looks like GISAID removed the agreement box between clicking on download and actually downloading the fasta/metadata
    #WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.XPATH, "//*[starts-with(@id, 'sysoverlay-wid')]")))
    #time.sleep(1)
    #iframe = driver.find_element(By.XPATH, "//*[starts-with(@id, 'sysoverlay-wid')]")
    #driver.switch_to.frame(iframe)
    #WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.CLASS_NAME, "sys-event-hook")))
    #checkbox = driver.find_elements(By.CLASS_NAME, "sys-event-hook")[0].click()
    #time.sleep(3)
    #checkbox = driver.find_elements(By.CLASS_NAME, "sys-event-hook")[2].click()
    print("Downloading metadata...")

    time.sleep(3)
    while (len(glob.glob("metadata*.xz.part")) != 0):
        time.sleep(10)
    shutil.move(glob.glob("metadata*.xz")[0], args.outfile)
    
    driver.quit()
    print("GSD metadata download completed.")