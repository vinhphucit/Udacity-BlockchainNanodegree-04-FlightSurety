
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
                displayAirlineAddress(airline, DOM.elid("airlinesForFund"));                
            });
        });

        contract.getFlightKeys((error, result)=>{
            result.forEach(flight => {
                displayAirlineAddress(flight, DOM.elid("registeredFlights"));                
            });
        })

        // Register an Airline
        DOM.elid('submit-register-airline').addEventListener('click', () => {
            let registeredAirline = DOM.elid('airline-address').value;
            // Write transaction
            contract.registerAirline(registeredAirline, (error, result) => {
                console.log('registerAirline',error, result);
                if (!error) {
                    displayAirlineAddress(registeredAirline, DOM.elid("airlinesForFund"));                 
                }
            });
        })
        DOM.elid('submit-register-flight').addEventListener('click', () => {

            let flightNumber = DOM.elid('flight-number').value;
            let flightTime = DOM.elid('flight-time').value;
            // Write transaction
            contract.registerFlight(flightNumber,flightTime, (error, result) => {
                console.log('registerFlight', error, result)
            });
        })

        DOM.elid('query-flight-info').addEventListener('click', () => {
            let flightKey = DOM.elid('registeredFlights').value;
            // Write transaction
            contract.getFlightByKey(flightKey, (error, result) => {
                console.log('getFlightByKey', error, result)
            });
        })

        // Register an Airline
        DOM.elid('submit-fund-airline').addEventListener('click', () => {

            let fundAirlineValue = DOM.elid('fund-airline').value;
            // Write transaction
            contract.fundAirline(fundAirlineValue, (error, result) => {
                console.log('fundAirline', error, result)
            });
        })
        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                displayOperationStatus('Oracles', 'Trigger oracles', [{ label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp }]);
            });
        })
        DOM.elid('query-funded-airline').addEventListener('click', () => {
            let flight = DOM.elid('airlinesForFund').value;

            contract.fetchFundByAirline(flight, (error, result) => {
                alert(`fund by airline ${result} ether`)
            });
        })
    });


})();
function displayAirlineAddress(airline, parentEl) {
    let el = document.createElement("option");
    el.text = airline;
    el.value = airline;
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
