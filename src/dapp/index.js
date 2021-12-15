
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async () => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            displayOperationStatus('Operational Status', 'Check if contract is operational', [{ label: 'Operational Status', error: error, value: result }]);
        });

        contract.fetchRegisteredAirlineAddresses((error, result) => {
            result.forEach(airline => {
                displayList(airline, airline, DOM.elid("airlinesForFund"));
            });
        });
        contract.fetchActivatedAirlineAddresses((error, result) => {
            console.log('fetchActivatedAirlineAddresses',error, result);
            if (!error) {
                result.forEach(airline => {
                    displayList(airline, airline, DOM.elid("activatedAirlines"));
                });
            }
        });
        getFlightKeys();

        DOM.elid('query-funded-insurance').addEventListener('click', () => {
            let flight = DOM.elid('registeredFlights').value;
            // Write transaction
            contract.getFundedInsuranceAmount(flight, (error, amount, claimAmount) => {

                alert(`You already bought ${amount} ether, claimAmount is ${claimAmount}`);
            });
        });

        DOM.elid('withdraw').addEventListener('click', () => {
            let flight = DOM.elid('registeredFlights').value;
            // Write transaction
            contract.withdraw((error, result) => {
                if (!error)
                    alert(`You withdrawed from ${flight} successfully`);
            });
        });
        DOM.elid('withdrawable').addEventListener('click', () => {

            contract.getWithdrawableInsurance((error, result) => {
                if (!error)
                    alert(`You withdrawed from ${flight} successfully`);
            });
        });
        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('registeredFlights').value;
            let amount = DOM.elid('insurance-amount').value;
            // Write transaction
            contract.buyInsurance(flight, amount, (error, result) => {
                console.log('buyInsurance', error, result);
            });
        });

        // Register an Airline
        DOM.elid('submit-register-airline').addEventListener('click', () => {
            let airlineAddress = DOM.elid('airline-address').value;
            let airlineName = DOM.elid('airline-name').value;
            // Write transaction
            contract.registerAirline(airlineAddress,airlineName, (error, result) => {
                console.log('registerAirline', error, result);
                if (!error) {
                    displayList(airlineAddress, airlineAddress, DOM.elid("airlinesForFund"));
                }
            });
        })
        DOM.elid('submit-register-flight').addEventListener('click', () => {

            let flightNumber = DOM.elid('flight-number').value;
            let flightTime = DOM.elid('flight-time').value;
            // Write transaction
            contract.registerFlight(flightNumber, flightTime, (error, result) => {
                if (!error) {
                    getFlightKeys();
                    return;
                }
                console.log(error);
            });
        })

        DOM.elid('query-flight-info').addEventListener('click', () => {
            let flightKey = DOM.elid('registeredFlights').value;
            // Write transaction
            contract.getFlightByKey(flightKey, (error, result) => {
                const { airline, flightNumber, isRegistered, statusCode, timestamp } = result
                alert(`Airline: ${airline} \nFlight number: ${flightNumber} \nTimestamp: ${timestamp} \nStatusCode: ${statusCode}`)
            });
        })
        DOM.elid('fetch-flight-status').addEventListener('click', () => {
            let flightKey = DOM.elid('registeredFlights').value;
            // Write transaction
            contract.fetchFlightStatus(flightKey, (error, result) => {
                console.log('fetchFlightStatus', error, result);
            });
        })

        // Register an Airline
        DOM.elid('submit-fund-airline').addEventListener('click', () => {

            let fundAirlineValue = DOM.elid('fund-airline').value;
            // Write transaction
            contract.fundAirline(fundAirlineValue, (error, result) => {
                
                console.log('fundAirline', error, result);
                
                if (!error) {
                    emptyChild(DOM.elid("activatedAirlines"))
                    contract.fetchActivatedAirlineAddresses((error, result) => {
                        result.forEach(airline => {
                            displayList(airline, airline, DOM.elid("activatedAirlines"));
                        });
                    });
                }
            });
        })

        DOM.elid('query-funded-airline').addEventListener('click', () => {
            let flight = DOM.elid('activatedAirlines').value;

            contract.fetchFundByAirline(flight, (error, result) => {
                alert(`fund by airline ${result} ether`)
            });
        })
    });

    function getFlightKeys() {
        contract.getFlightKeys((error, result) => {
            emptyChild(DOM.elid("registeredFlights"));
            result.forEach(flight => {
                displayList(flight, flight, DOM.elid("registeredFlights"));
            });
        })
    }
})();
function emptyChild(parentEl) {
    parentEl.innerHTML = '';
}

function displayList(txt, value, parentEl) {
    let el = DOM.option();
    el.text = txt;
    el.value = value;
    parentEl.add(el);
}

function displayOperationStatus(title, description, results) {

    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));


    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}
